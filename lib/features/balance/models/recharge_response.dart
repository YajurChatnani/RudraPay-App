// Purpose: Recharge response and token models preserving immutable/issuer/mutable token schema.
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
    final parsedTokens = (json['tokens'] as List<dynamic>?)
            ?.map((t) => Token.fromJson(t as Map<String, dynamic>))
            .toList() ??
        [];

    return RechargeResponse(
      success: json['success'] ?? false,
      message: (json['message'] ?? json['msg'] ?? 'Recharge successful').toString(),
      userId: (json['userId'] ?? '').toString(),
      totalTokens: _asInt(json['totalTokens']) ?? parsedTokens.length,
      tokens: parsedTokens,
    );
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }
}

class Token {
  // Stored exactly as backend schema for secure persistence and future replay.
  final Map<String, dynamic> immutable;
  final Map<String, dynamic> issuer;
  final Map<String, dynamic> mutable;

  Token({
    required this.immutable,
    required this.issuer,
    required this.mutable,
  });

  // Derived helpers used by existing wallet logic.
  String get tokenId {
    return (immutable['token_id'] ??
            immutable['tokenId'] ??
            mutable['token_id'] ??
            mutable['tokenId'] ??
            '')
        .toString();
  }

  int get value {
    final raw = immutable['value'] ?? mutable['value'];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  bool get used {
    final status = (mutable['status'] ?? '').toString().toUpperCase();
    return status == 'SPENT';
  }

  String get signature => (issuer['signature'] ?? '').toString();

  String get createdAt {
    final mintInfo = immutable['mint_info'];
    if (mintInfo is Map) {
      return (mintInfo['timestamp'] ?? '').toString();
    }
    return '';
  }

  factory Token.fromJson(Map<String, dynamic> json) {
    // New backend shape nests fields inside immutable/issuer/mutable blocks.
    final immutableMap = json['immutable'] is Map
        ? Map<String, dynamic>.from(json['immutable'] as Map)
        : <String, dynamic>{
            'token_id': (json['token_id'] ?? json['tokenId'] ?? '').toString(),
            'value': json['value'] ?? 0,
            'mint_info': {
              'timestamp': int.tryParse((json['createdAt'] ?? '').toString()) ??
                  DateTime.now().millisecondsSinceEpoch,
              'expiry': null,
            },
          };

    final issuerMap = json['issuer'] is Map
        ? Map<String, dynamic>.from(json['issuer'] as Map)
        : <String, dynamic>{
            'server_id': (json['issuerServerId'] ?? '').toString(),
            'signature': (json['signature'] ?? '').toString(),
          };

    final mutableMap = json['mutable'] is Map
        ? Map<String, dynamic>.from(json['mutable'] as Map)
        : <String, dynamic>{
            'owner': {'public_key': null},
            'status': (json['used'] == true) ? 'SPENT' : 'UNSPENT',
            'lock_info': {
              'txn_id': null,
              'locked_to': null,
              'lock_hash': null,
              'encrypted_payload': null,
              'lock_timestamp': null,
              'lock_expiry': null,
            },
          };

    return Token(
      immutable: immutableMap,
      issuer: issuerMap,
      mutable: mutableMap,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      // Persist exactly in backend schema requested by server protocol.
      'immutable': immutable,
      'issuer': issuer,
      'mutable': mutable,
    };
  }
}
