// Purpose: Centralized environment-backed configuration values and validation helpers.
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  AppConfig();

  String get apiBaseUrl => dotenv.env['API_BASE_URL']?.trim() ?? '';
  // AUTH_BASE_URL is the primary source for auth endpoints.
  // API_BASE_URL is now optional and used only for legacy/fallback flows.
  String get authBaseUrl => dotenv.env['AUTH_BASE_URL']?.trim() ?? '';
  String get rechargeEndpoint => dotenv.env['RECHARGE_ENDPOINT']?.trim() ?? '';
  String get userId => dotenv.env['USER_ID']?.trim() ?? '';
  int get apiTimeout => int.tryParse(dotenv.env['API_TIMEOUT'] ?? '') ?? 30;

  // Minimum required config for app startup/auth flow.
  bool get isConfigured => authBaseUrl.isNotEmpty;

  String get configError {
    final missing = <String>[];
    // API_BASE_URL and USER_ID are optional with the new backend contract.
    if (authBaseUrl.isEmpty) missing.add('AUTH_BASE_URL');
    if (missing.isEmpty) return '';
    return 'Missing environment values: ${missing.join(', ')}';
  }
}
