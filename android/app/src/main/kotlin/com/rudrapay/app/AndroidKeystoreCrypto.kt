package com.rudrapay.app

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.nio.charset.StandardCharsets
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Creates and uses an AES key in Android Keystore for encryption and decryption.
 */
class AndroidKeystoreCrypto(
    private val keyAlias: String = DEFAULT_KEY_ALIAS
) {

    data class EncryptedPayload(
        val cipherTextBase64: String,
        val ivBase64: String
    )

    fun encrypt(plainText: String): EncryptedPayload {
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, getOrCreateSecretKey())

        val cipherText = cipher.doFinal(plainText.toByteArray(StandardCharsets.UTF_8))
        val iv = cipher.iv

        return EncryptedPayload(
            cipherTextBase64 = Base64.encodeToString(cipherText, Base64.NO_WRAP),
            ivBase64 = Base64.encodeToString(iv, Base64.NO_WRAP)
        )
    }

    fun decrypt(payload: EncryptedPayload): String {
        val cipher = Cipher.getInstance(TRANSFORMATION)

        val iv = Base64.decode(payload.ivBase64, Base64.NO_WRAP)
        val cipherText = Base64.decode(payload.cipherTextBase64, Base64.NO_WRAP)

        val spec = GCMParameterSpec(GCM_TAG_LENGTH_BITS, iv)
        cipher.init(Cipher.DECRYPT_MODE, getOrCreateSecretKey(), spec)

        val plainBytes = cipher.doFinal(cipherText)
        return String(plainBytes, StandardCharsets.UTF_8)
    }

    private fun getOrCreateSecretKey(): SecretKey {
        val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
        val existingKey = keyStore.getKey(keyAlias, null) as? SecretKey
        if (existingKey != null) return existingKey

        val keyGenerator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE)
        val keyGenParameterSpec = KeyGenParameterSpec.Builder(
            keyAlias,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(KEY_SIZE_BITS)
            .build()

        keyGenerator.init(keyGenParameterSpec)
        return keyGenerator.generateKey()
    }

    companion object {
        private const val ANDROID_KEYSTORE = "AndroidKeyStore"
        private const val TRANSFORMATION = "AES/GCM/NoPadding"
        private const val GCM_TAG_LENGTH_BITS = 128
        private const val KEY_SIZE_BITS = 256
        private const val DEFAULT_KEY_ALIAS = "rudrapay_aes_key"
    }
}
