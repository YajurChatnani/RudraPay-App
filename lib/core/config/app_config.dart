import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  AppConfig();

  String get apiBaseUrl => dotenv.env['API_BASE_URL']?.trim() ?? '';
  String get authBaseUrl => dotenv.env['AUTH_BASE_URL']?.trim() ?? apiBaseUrl;
  String get userId => dotenv.env['USER_ID']?.trim() ?? '';
  int get apiTimeout => int.tryParse(dotenv.env['API_TIMEOUT'] ?? '') ?? 30;

  bool get isConfigured => apiBaseUrl.isNotEmpty && authBaseUrl.isNotEmpty;

  String get configError {
    final missing = <String>[];
    if (apiBaseUrl.isEmpty) missing.add('API_BASE_URL');
    if (authBaseUrl.isEmpty) missing.add('AUTH_BASE_URL');
    if (userId.isEmpty) missing.add('USER_ID');
    if (missing.isEmpty) return '';
    return 'Missing environment values: ${missing.join(', ')}';
  }
}
