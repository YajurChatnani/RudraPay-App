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
    if (!_config.isConfigured) {
      throw AppException.config(_config.configError);
    }

    final url = Uri.parse('${_config.authBaseUrl}/login');
    final payload = {
      'identifier': identifier.trim(),
      'password': password,
    };

    try {
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

      final data = _decodeResponse(response);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final token = (data['token'] ?? '').toString();
        if (token.isEmpty) {
          throw AppException.unknown('Token missing in response');
        }

        final userDataRaw = data['user'];
        final userJson = userDataRaw is Map<String, dynamic> 
            ? userDataRaw 
            : (userDataRaw is Map ? Map<String, dynamic>.from(userDataRaw) : <String, dynamic>{});
        final user = userJson.isNotEmpty
            ? User.fromJson(userJson)
            : _fallbackUser(identifier: identifier);

        await TokenService.saveSession(token, user);
        return AuthResult(token: token, user: user);
      }

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
    if (!_config.isConfigured) {
      throw AppException.config(_config.configError);
    }

    final url = Uri.parse('${_config.authBaseUrl}/register');
    final payload = {
      'name': name.trim(),
      'age': age,
      'gender': gender.trim(),
      'phoneNumber': phoneNumber.trim(),
      'email': email.trim(),
      'password': password,
    };

    try {
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

      final data = _decodeResponse(response);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final token = (data['token'] ?? '').toString();
        if (token.isEmpty) {
          throw AppException.unknown('Token missing in response');
        }

        final userDataRaw = data['user'];
        final userJson = userDataRaw is Map<String, dynamic> 
            ? userDataRaw 
            : (userDataRaw is Map ? Map<String, dynamic>.from(userDataRaw) : <String, dynamic>{});
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

        await TokenService.saveSession(token, user);
        return AuthResult(token: token, user: user);
      }

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
    final message = data['msg'] ?? data['message'] ?? 'Request failed';
    if (statusCode == 400) throw AppException.badRequest(message);
    if (statusCode == 401) throw AppException.unauthorized(message);
    if (statusCode == 403) throw AppException.unauthorized(message);
    if (statusCode >= 500) throw AppException.server(message);
  }

  static User _fallbackUser({required String identifier}) {
    final isEmail = identifier.contains('@');
    final isPhone = identifier.startsWith('+');
    return User(
      id: _config.userId.isNotEmpty ? _config.userId : '',
      name: identifier,
      email: isEmail ? identifier : '',
      phoneNumber: isPhone ? identifier : '',
      balance: 0.0,
      createdAt: DateTime.now(),
    );
  }
}
