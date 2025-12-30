import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';
import '../models/recharge_response.dart';

class WalletService {
  static final _config = AppConfig();

  /// Recharge wallet with free tokens
  /// [amount] - The amount/number of tokens to recharge
  /// Returns [RechargeResponse] on success
  /// Throws [AppException] on error
  static Future<RechargeResponse> rechargeWallet(int amount) async {
    try {
      // Validate configuration
      if (!_config.isConfigured) {
        throw AppException.config(_config.configError);
      }

      final baseUrl = _config.apiBaseUrl;
      final userId = _config.userId;
      final url = Uri.parse('$baseUrl/recharge?userId=$userId&amount=$amount');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(
        Duration(seconds: _config.apiTimeout),
        onTimeout: () => throw AppException.timeout(null),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        return RechargeResponse.fromJson(jsonResponse);
      } else if (response.statusCode == 400) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        throw AppException.badRequest(
          jsonResponse['message'] ?? 'Invalid request. Please check the amount.',
        );
      } else if (response.statusCode == 401) {
        throw AppException.unauthorized('Unauthorized access. Please login again.');
      } else if (response.statusCode == 500) {
        throw AppException.server('Server error. Please try again later.');
      } else {
        throw AppException.unknown(
          'Failed to recharge. Error code: ${response.statusCode}',
        );
      }
    } on AppException {
      rethrow;
    } on http.ClientException catch (e) {
      throw AppException.network('Network error: ${e.message}');
    } catch (e) {
      throw AppException.unknown(e.toString());
    }
  }
}
