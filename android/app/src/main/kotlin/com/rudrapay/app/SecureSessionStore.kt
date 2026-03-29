package com.rudrapay.app

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import org.json.JSONObject

/**
 * SharedPreferences-compatible session storage using EncryptedSharedPreferences.
 *
 * This keeps the same key names used by the existing implementation so behavior remains stable,
 * while transparently encrypting values at rest.
 */
class SecureSessionStore(
    context: Context,
    encryptedPrefsName: String = DEFAULT_ENCRYPTED_PREFS_NAME,
    private val legacyPrefsName: String? = null
) {

    data class TokenObject(
        val accessToken: String,
        val refreshToken: String? = null,
        val userId: String? = null,
        val issuedAtEpochMs: Long? = null,
        val expiresAtEpochMs: Long? = null
    ) {
        fun toJsonString(): String {
            return JSONObject()
                .put("accessToken", accessToken)
                .put("refreshToken", refreshToken)
                .put("userId", userId)
                .put("issuedAtEpochMs", issuedAtEpochMs)
                .put("expiresAtEpochMs", expiresAtEpochMs)
                .toString()
        }

        companion object {
            fun fromJsonString(json: String): TokenObject {
                val obj = JSONObject(json)
                val accessToken = obj.optString("accessToken", "")
                require(accessToken.isNotEmpty()) { "accessToken is required" }

                return TokenObject(
                    accessToken = accessToken,
                    refreshToken = obj.optNullableString("refreshToken"),
                    userId = obj.optNullableString("userId"),
                    issuedAtEpochMs = obj.optNullableLong("issuedAtEpochMs"),
                    expiresAtEpochMs = obj.optNullableLong("expiresAtEpochMs")
                )
            }

            private fun JSONObject.optNullableString(name: String): String? {
                if (isNull(name)) return null
                return optString(name, null)
            }

            private fun JSONObject.optNullableLong(name: String): Long? {
                if (isNull(name)) return null
                return if (has(name)) optLong(name) else null
            }
        }
    }

    private val appContext = context.applicationContext

    private val masterKey = MasterKey.Builder(appContext)
        .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
        .build()

    private val prefs = EncryptedSharedPreferences.create(
        appContext,
        encryptedPrefsName,
        masterKey,
        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
    )

    init {
        migrateLegacyIfPresent()
    }

    // Compatibility methods matching the existing SharedPreferences token-service behavior.
    fun saveSession(token: String, userJson: String, userId: String) {
        prefs.edit()
            .putString(KEY_AUTH_TOKEN, token)
            .putString(KEY_AUTH_USER, userJson)
            .putString(KEY_USER_ID, userId)
            .apply()
    }

    fun getToken(): String? = prefs.getString(KEY_AUTH_TOKEN, null)

    fun getUserJson(): String? = prefs.getString(KEY_AUTH_USER, null)

    fun isLoggedIn(): Boolean = !getToken().isNullOrBlank()

    fun clearSession() {
        prefs.edit()
            .remove(KEY_AUTH_TOKEN)
            .remove(KEY_AUTH_USER)
            .remove(KEY_REFRESH_TOKEN)
            .remove(KEY_USER_ID)
            .remove(KEY_TOKEN_OBJECT)
            .apply()
    }

    fun saveToken(token: String) {
        prefs.edit().putString(KEY_AUTH_TOKEN, token).apply()
    }

    fun saveRefreshToken(token: String) {
        prefs.edit().putString(KEY_REFRESH_TOKEN, token).apply()
    }

    fun getRefreshToken(): String? = prefs.getString(KEY_REFRESH_TOKEN, null)

    fun saveUserId(userId: String) {
        prefs.edit().putString(KEY_USER_ID, userId).apply()
    }

    fun getUserId(): String? = prefs.getString(KEY_USER_ID, null)

    fun setString(key: String, value: String) {
        prefs.edit().putString(key, value).apply()
    }

    fun getString(key: String): String? = prefs.getString(key, null)

    fun setInt(key: String, value: Int) {
        prefs.edit().putInt(key, value).apply()
    }

    fun getInt(key: String): Int? = if (prefs.contains(key)) prefs.getInt(key, 0) else null

    fun removeKey(key: String) {
        prefs.edit().remove(key).apply()
    }

    // Token object APIs with JSON serialization/deserialization.
    fun saveTokenObject(tokenObject: TokenObject) {
        prefs.edit().putString(KEY_TOKEN_OBJECT, tokenObject.toJsonString()).apply()
    }

    fun getTokenObject(): TokenObject? {
        val raw = prefs.getString(KEY_TOKEN_OBJECT, null) ?: return null
        return try {
            TokenObject.fromJsonString(raw)
        } catch (_: Exception) {
            null
        }
    }

    private fun migrateLegacyIfPresent() {
        val legacyName = legacyPrefsName ?: return
        if (prefs.getBoolean(KEY_MIGRATION_DONE, false)) return

        val legacy: SharedPreferences =
            appContext.getSharedPreferences(legacyName, Context.MODE_PRIVATE)

        val keysToCopy = listOf(
            KEY_AUTH_TOKEN,
            KEY_AUTH_USER,
            KEY_REFRESH_TOKEN,
            KEY_USER_ID,
            KEY_TOKEN_OBJECT
        )

        val editor = prefs.edit()
        for (key in keysToCopy) {
            val value = legacy.getString(key, null) ?: legacy.getString("flutter.$key", null)
            if (!value.isNullOrEmpty()) {
                editor.putString(key, value)
            }
        }

        // Commit encrypted writes first; only purge legacy plaintext data after success.
        val migrationSaved = editor.commit()
        if (!migrationSaved) return

        val legacyEditor = legacy.edit()
        for (key in keysToCopy) {
            legacyEditor.remove(key)
            legacyEditor.remove("flutter.$key")
        }

        // Remove migration marker in plaintext store if it exists.
        legacyEditor.remove(KEY_MIGRATION_DONE)
        legacyEditor.remove("flutter.$KEY_MIGRATION_DONE")
        legacyEditor.commit()

        prefs.edit().putBoolean(KEY_MIGRATION_DONE, true).apply()
    }

    companion object {
        const val DEFAULT_ENCRYPTED_PREFS_NAME = "secure_session_prefs"

        private const val KEY_AUTH_TOKEN = "auth_token"
        private const val KEY_AUTH_USER = "auth_user"
        private const val KEY_REFRESH_TOKEN = "refresh_token"
        private const val KEY_USER_ID = "user_id"
        private const val KEY_TOKEN_OBJECT = "auth_token_object"
        private const val KEY_MIGRATION_DONE = "migration_done"
    }
}
