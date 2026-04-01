// Purpose: Wraps encrypted platform storage operations for secure read/write/delete of sensitive values.
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  static void _ensureSupportedPlatform() {
    if (kIsWeb) {
      throw UnsupportedError('Secure storage service is not available on web.');
    }

    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      throw UnsupportedError(
        'Secure storage service is only supported on Android and iOS.',
      );
    }
  }

  static Future<void> setString(String key, String value) async {
    _ensureSupportedPlatform();
    await _storage.write(key: key, value: value);
  }

  static Future<String?> getString(String key) async {
    _ensureSupportedPlatform();
    return _storage.read(key: key);
  }

  static Future<void> setInt(String key, int value) async {
    _ensureSupportedPlatform();
    await _storage.write(key: key, value: value.toString());
  }

  static Future<int?> getInt(String key) async {
    _ensureSupportedPlatform();
    final value = await _storage.read(key: key);
    if (value == null) return null;
    return int.tryParse(value);
  }

  static Future<void> remove(String key) async {
    _ensureSupportedPlatform();
    await _storage.delete(key: key);
  }
}
