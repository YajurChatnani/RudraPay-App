import 'dart:convert';

class TransactionBundle {
  final String txnId;
  final List<String> tokenIds;
  final Map<String, String> unlockKeys;

  const TransactionBundle({
    required this.txnId,
    required this.tokenIds,
    required this.unlockKeys,
  });

  factory TransactionBundle.fromJson(Map<String, dynamic> json) {
    final txnId = (json['txnId'] ?? json['txn_id'] ?? '').toString();
    final tokenIds = (json['tokenIds'] as List<dynamic>? ?? const <dynamic>[])
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList();

    final rawKeys = json['unlockKeys'] ?? json['keys'];
    final unlockKeys = <String, String>{};
    if (rawKeys is Map) {
      for (final entry in rawKeys.entries) {
        final key = entry.key.toString();
        final value = entry.value.toString();
        if (key.isNotEmpty && value.isNotEmpty) {
          unlockKeys[key] = value;
        }
      }
    }

    return TransactionBundle(
      txnId: txnId,
      tokenIds: tokenIds,
      unlockKeys: unlockKeys,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'txnId': txnId,
      'tokenIds': tokenIds,
      'unlockKeys': unlockKeys,
    };
  }

  Map<String, dynamic> toQrPayload() {
    return {
      'txn_id': txnId,
      'keys': unlockKeys,
    };
  }

  String toQrPayloadString() => jsonEncode(toQrPayload());

  static TransactionBundle fromQrPayloadString(String payload) {
    final parsed = jsonDecode(payload);
    if (parsed is! Map<String, dynamic>) {
      throw const FormatException('Invalid QR payload format');
    }

    final txnId = (parsed['txn_id'] ?? '').toString();
    if (txnId.isEmpty) {
      throw const FormatException('Missing txn_id in QR payload');
    }

    final keysRaw = parsed['keys'];
    if (keysRaw is! Map) {
      throw const FormatException('Missing keys map in QR payload');
    }

    final unlockKeys = <String, String>{};
    for (final entry in keysRaw.entries) {
      final tokenId = entry.key.toString();
      final unlockKey = entry.value.toString();
      if (tokenId.isNotEmpty && unlockKey.isNotEmpty) {
        unlockKeys[tokenId] = unlockKey;
      }
    }

    if (unlockKeys.isEmpty) {
      throw const FormatException('QR payload has no unlock keys');
    }

    return TransactionBundle(
      txnId: txnId,
      tokenIds: unlockKeys.keys.toList(growable: false),
      unlockKeys: unlockKeys,
    );
  }
}
