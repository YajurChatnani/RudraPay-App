import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../models/recharge_response.dart';
import '../models/transaction_bundle.dart';

class TokenLockException implements Exception {
  final String message;
  const TokenLockException(this.message);

  @override
  String toString() => message;
}

class BatchLockResult {
  final List<Token> updatedTokens;
  final TransactionBundle transactionBundle;

  const BatchLockResult({
    required this.updatedTokens,
    required this.transactionBundle,
  });
}

class TokenLockService {
  static const Uuid _uuid = Uuid();

  static BatchLockResult lockTokens({
    required List<Token> tokens,
    required String senderPrivKey,
    required String receiverPubKey,
    String? txnId,
    Duration lockDuration = const Duration(minutes: 10),
  }) {
    if (tokens.isEmpty) {
      throw const TokenLockException('No tokens provided for lock');
    }

    final batchTxnId = (txnId == null || txnId.trim().isEmpty) ? _uuid.v4() : txnId.trim();
    final now = DateTime.now().toUtc();
    final expiry = now.add(lockDuration);

    final updatedTokens = <Token>[];
    final unlockKeys = <String, String>{};

    for (final token in tokens) {
      final tokenId = token.tokenId;
      if (tokenId.isEmpty) {
        throw const TokenLockException('Token missing tokenId');
      }

      final status = _statusOf(token);
      if (status != 'UNSPENT') {
        throw TokenLockException('Token $tokenId is not UNSPENT');
      }

      final unlockKey = _sha256Hex('$senderPrivKey$tokenId$batchTxnId$receiverPubKey');
      final encryptedPayload = _encryptPayload(
        unlockKey,
        {
          'immutable': token.immutable,
          'issuer': token.issuer,
        },
      );
      final lockHash = _sha256Hex(unlockKey);

      final nextMutable = Map<String, dynamic>.from(token.mutable);
      final nextOwner = nextMutable['owner'] is Map
          ? Map<String, dynamic>.from(nextMutable['owner'] as Map)
          : <String, dynamic>{};
      nextOwner['public_key'] = receiverPubKey;
      nextMutable['owner'] = nextOwner;
      nextMutable['token_id'] = tokenId;
      nextMutable['value'] = token.value;
      nextMutable['status'] = 'LOCKED';
      nextMutable['lock_info'] = {
        'txn_id': batchTxnId,
        'locked_to': receiverPubKey,
        'lock_hash': lockHash,
        'encrypted_payload': encryptedPayload,
        'lock_timestamp': now.toIso8601String(),
        'lock_expiry': expiry.toIso8601String(),
      };

      updatedTokens.add(
        Token(
          immutable: Map<String, dynamic>.from(token.immutable),
          issuer: Map<String, dynamic>.from(token.issuer),
          mutable: nextMutable,
        ),
      );

      unlockKeys[tokenId] = unlockKey;
    }

    return BatchLockResult(
      updatedTokens: updatedTokens,
      transactionBundle: TransactionBundle(
        txnId: batchTxnId,
        tokenIds: unlockKeys.keys.toList(growable: false),
        unlockKeys: unlockKeys,
      ),
    );
  }

  static List<Token> unlockTransaction({
    required List<Token> tokens,
    required Map<String, String> unlockKeys,
    required String myPubKey,
  }) {
    if (tokens.isEmpty) {
      throw const TokenLockException('No locked tokens found for transaction');
    }

    final txnIds = <String>{};

    for (final token in tokens) {
      final tokenId = token.tokenId;
      if (tokenId.isEmpty) {
        throw const TokenLockException('Token missing tokenId');
      }

      final status = _statusOf(token);
      if (status != 'LOCKED') {
        throw TokenLockException('Token $tokenId is not LOCKED');
      }

      final lockInfo = _lockInfoOf(token);
      final txnId = (lockInfo['txn_id'] ?? '').toString();
      if (txnId.isEmpty) {
        throw TokenLockException('Token $tokenId missing txn_id');
      }
      txnIds.add(txnId);

      final lockedTo = (lockInfo['locked_to'] ?? '').toString();
      if (lockedTo != myPubKey) {
        throw TokenLockException('Token $tokenId is locked to another receiver');
      }

      final expiryRaw = (lockInfo['lock_expiry'] ?? '').toString();
      final expiry = DateTime.tryParse(expiryRaw)?.toUtc();
      if (expiry == null || DateTime.now().toUtc().isAfter(expiry)) {
        throw TokenLockException('Token $tokenId lock has expired');
      }

      final unlockKey = unlockKeys[tokenId];
      if (unlockKey == null || unlockKey.isEmpty) {
        throw TokenLockException('Missing unlockKey for token $tokenId');
      }

      final lockHash = (lockInfo['lock_hash'] ?? '').toString();
      if (lockHash.isEmpty || _sha256Hex(unlockKey) != lockHash) {
        throw TokenLockException('Invalid unlock key hash for token $tokenId');
      }

      final encryptedPayload = (lockInfo['encrypted_payload'] ?? '').toString();
      if (encryptedPayload.isEmpty) {
        throw TokenLockException('Missing encrypted payload for token $tokenId');
      }

      final payload = _decryptPayload(unlockKey, encryptedPayload);
      final immutable = payload['immutable'];
      final issuer = payload['issuer'];
      if (immutable is! Map || issuer is! Map) {
        throw TokenLockException('Decryption failed for token $tokenId');
      }
    }

    if (txnIds.length != 1) {
      throw const TokenLockException('txn_id mismatch across tokens');
    }

    final unlocked = <Token>[];
    for (final token in tokens) {
      final nextMutable = Map<String, dynamic>.from(token.mutable);
      final nextOwner = nextMutable['owner'] is Map
          ? Map<String, dynamic>.from(nextMutable['owner'] as Map)
          : <String, dynamic>{};
      nextOwner['public_key'] = myPubKey;
      nextMutable['owner'] = nextOwner;
      nextMutable.remove('token_id');
      nextMutable.remove('tokenId');
      nextMutable.remove('value');
      nextMutable['status'] = 'UNSPENT';
      nextMutable['lock_info'] = null;

      unlocked.add(
        Token(
          immutable: Map<String, dynamic>.from(token.immutable),
          issuer: Map<String, dynamic>.from(token.issuer),
          mutable: nextMutable,
        ),
      );
    }

    return unlocked;
  }

  static String buildQrPayload(TransactionBundle bundle) {
    return bundle.toQrPayloadString();
  }

  static TransactionBundle parseQrPayload(String qrPayload) {
    return TransactionBundle.fromQrPayloadString(qrPayload);
  }

  static String _statusOf(Token token) {
    return (token.mutable['status'] ?? '').toString().toUpperCase();
  }

  static Map<String, dynamic> _lockInfoOf(Token token) {
    final lockInfo = token.mutable['lock_info'];
    if (lockInfo is Map) {
      return Map<String, dynamic>.from(lockInfo);
    }
    return <String, dynamic>{};
  }

  static String _sha256Hex(String input) {
    return sha256.convert(utf8.encode(input)).toString();
  }

  static String _encryptPayload(String unlockKey, Map<String, dynamic> payload) {
    final iv = _secureRandomBytes(16);
    final plainBytes = Uint8List.fromList(utf8.encode(jsonEncode(payload)));

    final encrypted = _xorWithKeystream(
      plainBytes,
      keyMaterial: unlockKey,
      iv: iv,
    );

    return jsonEncode({
      'alg': 'AES-CTR',
      'iv': base64Encode(iv),
      'ciphertext': base64Encode(encrypted),
    });
  }

  static Map<String, dynamic> _decryptPayload(String unlockKey, String encryptedPayload) {
    final parsed = jsonDecode(encryptedPayload);
    if (parsed is! Map<String, dynamic>) {
      throw const TokenLockException('Encrypted payload format invalid');
    }

    final ivBase64 = (parsed['iv'] ?? '').toString();
    final ciphertextBase64 = (parsed['ciphertext'] ?? '').toString();
    if (ivBase64.isEmpty || ciphertextBase64.isEmpty) {
      throw const TokenLockException('Encrypted payload missing iv/ciphertext');
    }

    final iv = base64Decode(ivBase64);
    final encrypted = base64Decode(ciphertextBase64);

    final decrypted = _xorWithKeystream(
      Uint8List.fromList(encrypted),
      keyMaterial: unlockKey,
      iv: Uint8List.fromList(iv),
    );

    final decoded = jsonDecode(utf8.decode(decrypted));
    if (decoded is! Map<String, dynamic>) {
      throw const TokenLockException('Decrypted payload format invalid');
    }

    return decoded;
  }

  static Uint8List _secureRandomBytes(int length) {
    final rnd = Random.secure();
    return Uint8List.fromList(List<int>.generate(length, (_) => rnd.nextInt(256)));
  }

  // Deterministic stream derived from HMAC-SHA256(key, iv || counter) and XORed with data.
  static Uint8List _xorWithKeystream(
    Uint8List input, {
    required String keyMaterial,
    required Uint8List iv,
  }) {
    final key = utf8.encode(keyMaterial);
    final hmac = Hmac(sha256, key);
    final output = Uint8List(input.length);

    var offset = 0;
    var counter = 0;
    while (offset < input.length) {
      final blockInput = BytesBuilder(copy: false)
        ..add(iv)
        ..add(_intToBytes(counter));
      final block = hmac.convert(blockInput.toBytes()).bytes;

      for (var i = 0; i < block.length && offset < input.length; i++) {
        output[offset] = input[offset] ^ block[i];
        offset++;
      }
      counter++;
    }

    return output;
  }

  static List<int> _intToBytes(int value) {
    return <int>[
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ];
  }
}
