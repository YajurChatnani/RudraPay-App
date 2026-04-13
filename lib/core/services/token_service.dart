// Purpose: Manages auth session persistence (JWT, user payload, and related token fields).
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import 'secure_storage_service.dart';

class TokenService {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'auth_user';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userIdKey = 'user_id';
  static User? _cachedUser;
  static String? _cachedUserJson;

  static Future<void> saveSession(String token, User user) async {
    // User object is serialized before persisting.
    // SecureStorageService uses platform secure storage (encrypted at-rest)
    // on supported mobile targets.
    final userJson = jsonEncode(user.toJson());
    await SecureStorageService.setString(_tokenKey, token);
    await SecureStorageService.setString(_userKey, userJson);
    await SecureStorageService.setString(_userIdKey, user.id);
    _cachedUser = user;
    _cachedUserJson = userJson;
  }

  static Future<String?> getToken() async {
    return SecureStorageService.getString(_tokenKey);
  }

  static Future<User?> getUser() async {
    if (_cachedUser != null) {
      return _cachedUser;
    }

    // Read encrypted user payload and deserialize it back into User model.
    final jsonString = await SecureStorageService.getString(_userKey);

    if (jsonString == null) return null;

    if (_cachedUserJson != null && _cachedUserJson == jsonString && _cachedUser != null) {
      return _cachedUser;
    }

    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final user = User.fromJson(data);
      _cachedUser = user;
      _cachedUserJson = jsonString;
      return user;
    } catch (e) {
      _log('Failed to parse stored user data. Clearing corrupted session user data.');
      _log('User parse error type: ${e.runtimeType}');

      try {
        await SecureStorageService.remove(_userKey);
        await SecureStorageService.remove(_userIdKey);
        _cachedUser = null;
        _cachedUserJson = null;
      } catch (cleanupError) {
        _log('Failed to clear corrupted user data.');
        _log('Cleanup error type: ${cleanupError.runtimeType}');
      }

      return null;
    }
  }

  static void _log(String message) {
    if (kDebugMode) {
      debugPrint('[TOKEN_SERVICE] $message');
    }
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  static Future<void> clearSession() async {
    await SecureStorageService.remove(_tokenKey);
    await SecureStorageService.remove(_userKey);
    await SecureStorageService.remove(_refreshTokenKey);
    await SecureStorageService.remove(_userIdKey);
    _cachedUser = null;
    _cachedUserJson = null;
  }

  // Legacy helpers kept for compatibility
  static Future<void> saveToken(String token) async => saveSession(token, User(id: '', name: '', email: '', phoneNumber: '', balance: 0.0, createdAt: DateTime.now()));

  static Future<void> saveRefreshToken(String token) async {
    await SecureStorageService.setString(_refreshTokenKey, token);
  }

  static Future<String?> getRefreshToken() async {
    return SecureStorageService.getString(_refreshTokenKey);
  }

  static Future<void> saveUserId(String userId) async {
    await SecureStorageService.setString(_userIdKey, userId);
  }

  static Future<String?> getUserId() async {
    return SecureStorageService.getString(_userIdKey);
  }
}
