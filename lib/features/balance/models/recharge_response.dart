class RechargeResponse {
  final bool success;
  final String message;
  final String userId;
  final int totalTokens;
  final List<Token> tokens;

  RechargeResponse({
    required this.success,
    required this.message,
    required this.userId,
    required this.totalTokens,
    required this.tokens,
  });

  factory RechargeResponse.fromJson(Map<String, dynamic> json) {
    return RechargeResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      userId: json['userId'] ?? '',
      totalTokens: json['totalTokens'] ?? 0,
      tokens: (json['tokens'] as List<dynamic>?)
              ?.map((t) => Token.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class Token {
  final String tokenId;
  final int value;
  final bool used;
  final String signature;
  final String createdAt;

  Token({
    required this.tokenId,
    required this.value,
    required this.used,
    required this.signature,
    required this.createdAt,
  });

  factory Token.fromJson(Map<String, dynamic> json) {
    return Token(
      tokenId: json['tokenId'] ?? '',
      value: json['value'] ?? 0,
      used: json['used'] ?? false,
      signature: json['signature'] ?? '',
      createdAt: json['createdAt'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tokenId': tokenId,
      'value': value,
      'used': used,
      'signature': signature,
      'createdAt': createdAt,
    };
  }
}
