// Purpose: Calls auth APIs (login/register/logout) and persists authenticated session data.
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../errors/app_exception.dart';
import '../models/user_model.dart';
import 'token_service.dart';

class AuthResult {
  final String token;
  final User user;

  const AuthResult({required this.token, required this.user});
}

class AuthService {
  static final AppConfig _config = AppConfig();

  static Future<AuthResult> login({
    required String identifier,
    required String password,
  }) async {
    // Fail fast when environment variables are not configured.
    if (!_config.isConfigured) {
      throw AppException.config(_config.configError);
    }

    // Login endpoint (currently expected as: <AUTH_BASE_URL>/login).
    final url = Uri.parse('${_config.authBaseUrl}/login');

    // Backend contract accepts identifier as either phone number or email.
    final payload = {
      'identifier': identifier.trim(),
      'password': password,
    };

    try {
      // Send login request with JSON body.
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(
            Duration(seconds: _config.apiTimeout),
            onTimeout: () => throw AppException.timeout(null),
          );

      // Decode once and re-use for all status branches.
      final data = _decodeResponse(response);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final token = (data['token'] ?? '').toString();
        if (token.isEmpty) {
          throw AppException.unknown('Token missing in response');
        }

        // API can return either strongly-typed map or dynamic map.
        final userDataRaw = data['user'];
        final userJson = userDataRaw is Map<String, dynamic>
            ? userDataRaw
            : (userDataRaw is Map ? Map<String, dynamic>.from(userDataRaw) : <String, dynamic>{});

        // If backend returns minimal user object, fallback to identifier-derived shape.
        // TokenService.saveSession stores this user JSON in secure storage,
        // so user details remain encrypted at-rest like other auth data.
        final user = userJson.isNotEmpty
            ? User.fromJson(userJson)
            : _fallbackUser(identifier: identifier);

        // Persist auth session (token + user) in secure encrypted storage.
        await TokenService.saveSession(token, user);
        return AuthResult(token: token, user: user);
      }

      // Handle non-success statuses with domain-aware error mapping.
      _throwForStatus(response.statusCode, data);
      throw AppException.unknown('Login failed');
    } on AppException {
      rethrow;
    } on http.ClientException catch (e) {
      throw AppException.network('Network error: ${e.message}');
    } catch (e) {
      throw AppException.unknown(e.toString());
    }
  }

  static Future<AuthResult> register({
    required String name,
    required int age,
    required String gender,
    required String phoneNumber,
    required String email,
    required String password,
  }) async {
    // Fail fast when environment variables are not configured.
    if (!_config.isConfigured) {
      throw AppException.config(_config.configError);
    }

    // Register endpoint (currently expected as: <AUTH_BASE_URL>/register).
    final url = Uri.parse('${_config.authBaseUrl}/register');

    // Keep this payload in sync with backend contract.
    final payload = {
      'name': name.trim(),
      'age': age,
      'gender': gender.trim(),
      'phoneNumber': phoneNumber.trim(),
      'email': email.trim(),
      'password': password,
    };

    try {
      // Send registration request with JSON body.
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(
            Duration(seconds: _config.apiTimeout),
            onTimeout: () => throw AppException.timeout(null),
          );

      // Decode once and re-use for all status branches.
      final data = _decodeResponse(response);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final token = (data['token'] ?? '').toString();
        if (token.isEmpty) {
          throw AppException.unknown('Token missing in response');
        }

        // API can return either strongly-typed map or dynamic map.
        final userDataRaw = data['user'];
        final userJson = userDataRaw is Map<String, dynamic>
            ? userDataRaw
            : (userDataRaw is Map ? Map<String, dynamic>.from(userDataRaw) : <String, dynamic>{});

        // If backend returns minimal user object, fallback to submitted values.
        // TokenService.saveSession stores this user JSON in secure storage,
        // so user details remain encrypted at-rest like other auth data.
        final user = userJson.isNotEmpty
            ? User.fromJson(userJson)
            : User(
                id: userJson['id']?.toString() ?? '',
                name: name.trim(),
                email: email.trim(),
                phoneNumber: phoneNumber.trim(),
                balance: 0.0,
                createdAt: DateTime.now(),
              );

        // Persist auth session (token + user) in secure encrypted storage.
        await TokenService.saveSession(token, user);
        return AuthResult(token: token, user: user);
      }

      // Handle non-success statuses with domain-aware error mapping.
      _throwForStatus(response.statusCode, data);
      throw AppException.unknown('Registration failed');
    } on AppException {
      rethrow;
    } on http.ClientException catch (e) {
      throw AppException.network('Network error: ${e.message}');
    } catch (e) {
      throw AppException.unknown(e.toString());
    }
  }

  static Future<void> logout() async {
    await TokenService.clearSession();
  }

  static Map<String, dynamic> _decodeResponse(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return {};
    } catch (_) {
      return {};
    }
  }

  static void _throwForStatus(int statusCode, Map<String, dynamic> data) {
    // Backend may return either `msg` or `message`; normalize to String.
    final message = (data['msg'] ?? data['message'] ?? 'Request failed').toString();

    if (statusCode == 400) {
      // Explicitly normalize duplicate-user response so UI can show a stable message.
      final normalized = message.toLowerCase();
      if (normalized.contains('user already exists') ||
          normalized.contains('already exists')) {
        throw AppException.badRequest('User already exists');
      }
      throw AppException.badRequest(message);
    }

    if (statusCode == 401) throw AppException.unauthorized(message);
    if (statusCode == 403) throw AppException.unauthorized(message);
    if (statusCode >= 500) throw AppException.server(message);
  }

  static User _fallbackUser({required String identifier}) {
    // Detect if identifier is email or phone for fallback user shaping.
    final value = identifier.trim();
    final isEmail = value.contains('@');
    final isPhone = RegExp(r'^\+?[0-9]{7,15}$').hasMatch(value);
    return User(
      id: _config.userId.isNotEmpty ? _config.userId : '',
      name: value,
      email: isEmail ? value : '',
      phoneNumber: isPhone ? value : '',
      balance: 0.0,
      createdAt: DateTime.now(),
    );
  }
}
