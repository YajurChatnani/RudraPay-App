import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/recharge_response.dart';

class WalletService {
  static const String _baseUrl = 'https://wallet-api-77kp.onrender.com/api/wallet';
  static const String _userId = 'USER_TEST'; // Constant user ID for now

  /// Recharge wallet with free tokens
  /// [amount] - The amount/number of tokens to recharge
  /// Returns [RechargeResponse] on success
  /// Throws exception on error
  static Future<RechargeResponse> rechargeWallet(int amount) async {
    try {
      final url = Uri.parse('$_baseUrl/recharge?userId=$_userId&amount=$amount');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Request timeout. Please try again.'),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        return RechargeResponse.fromJson(jsonResponse);
      } else if (response.statusCode == 400) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(
          jsonResponse['message'] ?? 'Invalid request. Please check the amount.',
        );
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized. Please login again.');
      } else if (response.statusCode == 500) {
        throw Exception('Server error. Please try again later.');
      } else {
        throw Exception(
          'Failed to recharge. Error code: ${response.statusCode}',
        );
      }
    } on http.ClientException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}
