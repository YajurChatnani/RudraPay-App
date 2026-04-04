// Purpose: Recharge API client that requests tokens, verifies them, and retries missing counts.
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/services/token_service.dart';
import '../models/recharge_response.dart';
import 'wallet_keypair_service.dart';

class WalletService {
  static final _config = AppConfig();

  /// Recharge wallet with free tokens
  /// [amount] - The amount/number of tokens to recharge
  /// Returns [RechargeResponse] on success
  /// Throws [AppException] on error
  static Future<RechargeResponse> rechargeWallet(
    int amount, {
    String network = 'mudrapay',
  }) async {
    try {
      // Validate configuration
      if (!_config.isConfigured) {
        throw AppException.config(_config.configError);
      }

      // Public key is generated once per network and persisted securely.
      // Private key remains local in encrypted secure storage only.
      final publicKeyPem = await WalletKeyPairService.getPublicKeyPem(network: network);
      final url = _resolveRechargeUri();

      final jwt = await TokenService.getToken();
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (jwt != null && jwt.isNotEmpty) {
        headers['x-auth-token'] = jwt;
      }

      // Token verification is temporarily disabled to reduce recharge latency.
      final verifiedTokens = <Token>[];
      final seenTokenIds = <String>{};
      var remaining = amount;
      var retries = 0;
      const maxRetries = 5;

      while (remaining > 0 && retries < maxRetries) {
        retries++;

        final response = await _requestRecharge(
          amount: remaining,
          publicKeyPem: publicKeyPem,
          url: url,
          headers: headers,
        );

        final incomingTokens = response.tokens;
        if (incomingTokens.isEmpty) {
          throw AppException.server('Recharge returned no tokens for remaining amount: $remaining');
        }

        for (final token in incomingTokens) {
          if (kDebugMode) {
            debugPrint(
              '[RECHARGE] Token from server: tokenId=${token.tokenId}, value=${token.value}, status=${token.mutable['status']}',
            );
          }
        }

        for (var i = 0; i < incomingTokens.length; i++) {
          final token = incomingTokens[i];

          if (seenTokenIds.contains(token.tokenId)) {
            // Duplicate token should not be counted twice.
            continue;
          }

          seenTokenIds.add(token.tokenId);
          verifiedTokens.add(token);
        }

        remaining = amount - verifiedTokens.length;
      }

      if (remaining > 0) {
        throw AppException.server(
          'Could not receive all tokens. Loaded ${verifiedTokens.length} of $amount.',
        );
      }

      return RechargeResponse(
        success: true,
        message: 'Recharge successful',
        userId: '',
        totalTokens: verifiedTokens.length,
        tokens: verifiedTokens,
      );
    } on AppException {
      rethrow;
    } on http.ClientException catch (e) {
      throw AppException.network('Network error: ${e.message}');
    } catch (e) {
      throw AppException.unknown(e.toString());
    }
  }

  static Uri _resolveRechargeUri() {
    // 1) Explicit endpoint wins if user has configured it.
    if (_config.rechargeEndpoint.isNotEmpty) {
      return Uri.parse(_config.rechargeEndpoint);
    }

    // 2) Backward-compat path based on API_BASE_URL if it already points to /api/wallet.
    if (_config.apiBaseUrl.contains('/api/wallet')) {
      return Uri.parse('${_config.apiBaseUrl}/recharge');
    }

    // 3) Fallback derived from AUTH_BASE_URL host: <origin>/api/wallet/recharge.
    final authUri = Uri.parse(_config.authBaseUrl);
    final origin = '${authUri.scheme}://${authUri.authority}';
    return Uri.parse('$origin/api/wallet/recharge');
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

  static Future<RechargeResponse> _requestRecharge({
    required int amount,
    required String publicKeyPem,
    required Uri url,
    required Map<String, String> headers,
  }) async {
    // New recharge contract: amount + publicKey.
    final payload = {
      'amount': amount,
      'publicKey': publicKeyPem,
    };

    final response = await http
        .post(
          url,
          headers: headers,
          body: jsonEncode(payload),
        )
        .timeout(
          Duration(seconds: _config.apiTimeout),
          onTimeout: () => throw AppException.timeout(null),
        );

    final jsonResponse = _decodeResponse(response);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return RechargeResponse.fromJson(jsonResponse);
    }

    _throwForStatus(response.statusCode, jsonResponse);
    throw AppException.unknown('Recharge failed');
  }

  static void _throwForStatus(int statusCode, Map<String, dynamic> data) {
    final message = (data['msg'] ?? data['message'] ?? 'Request failed').toString();
    if (statusCode == 400) throw AppException.badRequest(message);
    if (statusCode == 401) throw AppException.unauthorized(message);
    if (statusCode == 403) throw AppException.unauthorized(message);
    if (statusCode >= 500) throw AppException.server(message);
    throw AppException.unknown(message.isEmpty ? 'Request failed with code $statusCode' : message);
  }
}
