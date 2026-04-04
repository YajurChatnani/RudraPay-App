// Purpose: Token verification is temporarily disabled.
import 'package:flutter/foundation.dart';

import '../models/recharge_response.dart';

class TokenVerificationResult {
  final String tokenId;
  final bool isValid;
  final String? reason;

  const TokenVerificationResult({
    required this.tokenId,
    required this.isValid,
    this.reason,
  });
}

class TokenVerificationService {
  static void _log(String message) {
    if (kDebugMode) {
      debugPrint('[TOKEN_VERIFY] $message');
    }
  }

  // Verification is temporarily disabled to reduce latency.
  static Future<bool> isTokenValid(Token token) async {
    _log('isTokenValid disabled for tokenId=${token.tokenId}');
    return true;
  }

  // Verification is temporarily disabled to reduce latency.
  static Future<TokenVerificationResult> verifyToken(Token token) async {
    _log('verifyToken disabled for tokenId=${token.tokenId}');
    return TokenVerificationResult(
      tokenId: token.tokenId,
      isValid: true,
      reason: 'Verification temporarily disabled',
    );
  }

  // Verification is temporarily disabled to reduce latency.
  static Future<List<TokenVerificationResult>> verifyTokens(
    Iterable<Token> tokens,
  ) async {
    _log('verifyTokens disabled for ${tokens.length} tokens');
    return tokens
        .map(
          (token) => TokenVerificationResult(
            tokenId: token.tokenId,
            isValid: true,
            reason: 'Verification temporarily disabled',
          ),
        )
        .toList(growable: false);
  }
}
