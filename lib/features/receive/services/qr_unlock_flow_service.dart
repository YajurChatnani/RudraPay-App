import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../../../core/utils/async_timing.dart';
import '../../balance/models/recharge_response.dart';
import '../../balance/models/transaction_bundle.dart';
import '../../balance/services/storage_service.dart';
import '../../balance/services/token_lock_service.dart';

class UnlockPreview {
  final String txnId;
  final int tokenCount;
  final int totalValue;

  const UnlockPreview({
    required this.txnId,
    required this.tokenCount,
    required this.totalValue,
  });
}

class UnlockResult {
  final String txnId;
  final int tokenCount;
  final int totalValue;
  final List<Token> unlockedTokens;

  const UnlockResult({
    required this.txnId,
    required this.tokenCount,
    required this.totalValue,
    required this.unlockedTokens,
  });
}

class QrUnlockFlowService {
  static final Map<String, List<Token>> _validatedTokenCache = <String, List<Token>>{};

  static void cacheLockedTokens(String txnId, List<Token> tokens) {
    if (txnId.trim().isEmpty || tokens.isEmpty) return;
    _validatedTokenCache[txnId.trim()] = List<Token>.unmodifiable(tokens);
  }

  static void _log(String message) {
    if (kDebugMode) {
      debugPrint('[QR-UNLOCK] $message');
    }
  }

  static Future<UnlockPreview> buildPreview({
    required String qrPayload,
    required String myPubKey,
    List<Token>? preloadedLockedTokens,
  }) async {
    _log('buildPreview started');
    final bundle = TokenLockService.parseQrPayload(qrPayload);
    _log('Parsed QR bundle txnId=${bundle.txnId}, keys=${bundle.unlockKeys.length}');
    final lockedTokens = await traceAwait(
      '[QR-UNLOCK] _loadAndValidateLockedTokens preview',
      _loadAndValidateLockedTokens(
        bundle,
        myPubKey,
        preloadedLockedTokens: preloadedLockedTokens,
      ),
    );
    cacheLockedTokens(bundle.txnId, lockedTokens);
    _log('Loaded and validated locked tokens count=${lockedTokens.length}');

    final totalValue = lockedTokens.fold<int>(0, (sum, token) {
      final payload = token.mutable['lock_info'];
      if (payload is! Map) return sum;
      return sum + (token.value);
    });
    _log('Preview computed totalValue=$totalValue');

    return UnlockPreview(
      txnId: bundle.txnId,
      tokenCount: lockedTokens.length,
      totalValue: totalValue,
    );
  }

  static Future<UnlockResult> confirmAndUnlock({
    required String qrPayload,
    required String myPubKey,
    List<Token>? preloadedLockedTokens,
  }) async {
    _log('confirmAndUnlock started');
    final bundle = TokenLockService.parseQrPayload(qrPayload);
    _log('Parsed QR bundle for unlock txnId=${bundle.txnId}');
    final cachedTokens = _validatedTokenCache.remove(bundle.txnId);
    final List<Token> lockedTokens = cachedTokens ?? await traceAwait<List<Token>>(
      '[QR-UNLOCK] _loadAndValidateLockedTokens unlock',
      _loadAndValidateLockedTokens(
        bundle,
        myPubKey,
        preloadedLockedTokens: preloadedLockedTokens,
      ),
    );
    _log('Validated locked tokens before unlock count=${lockedTokens.length}');

    final unlocked = TokenLockService.unlockTransaction(
      tokens: lockedTokens,
      unlockKeys: bundle.unlockKeys,
      myPubKey: myPubKey,
    );
    _log('unlockTransaction succeeded count=${unlocked.length}');
    for (final token in unlocked) {
      _log('Unlocked token tokenId=${token.tokenId}, value=${token.value}, status=${token.mutable['status']}');
    }

    final persisted = await traceAwait('[QR-UNLOCK] StorageService.overwriteTokensFast', StorageService.overwriteTokensFast(unlocked));
    if (!persisted) {
      _log('Persistence failed for unlocked tokens');
      throw const TokenLockException('Failed to persist unlocked tokens');
    }
    _log('Unlocked tokens persisted successfully');

    final totalValue = unlocked.fold<int>(0, (sum, token) => sum + token.value);
    _log('confirmAndUnlock complete txnId=${bundle.txnId}, totalValue=$totalValue');

    return UnlockResult(
      txnId: bundle.txnId,
      tokenCount: unlocked.length,
      totalValue: totalValue,
      unlockedTokens: unlocked,
    );
  }

  static Future<List<Token>> _loadAndValidateLockedTokens(
    TransactionBundle bundle,
    String myPubKey,
    {List<Token>? preloadedLockedTokens}
  ) async {
    _log('Loading locked tokens for txnId=${bundle.txnId}');
    final cachedTokens = preloadedLockedTokens ?? _validatedTokenCache[bundle.txnId];
    final List<Token> lockedTokens = cachedTokens ?? await traceAwait<List<Token>>('[QR-UNLOCK] StorageService.getTokensByTxnId', StorageService.getTokensByTxnId(bundle.txnId));
    if (lockedTokens.isEmpty) {
      _log('No locked tokens found for txnId=${bundle.txnId}');
      throw const TokenLockException('Token not found for txn_id');
    }

    final selected = <Token>[];

    for (final token in lockedTokens) {
      final status = (token.mutable['status'] ?? '').toString().toUpperCase();
      if (status != 'LOCKED') {
        _log('Token state invalid tokenId=${token.tokenId}, status=$status');
        throw TokenLockException('Token not LOCKED: ${token.tokenId}');
      }

      final lockInfo = token.mutable['lock_info'];
      if (lockInfo is! Map) {
        _log('lock_info missing tokenId=${token.tokenId}');
        throw TokenLockException('Lock info missing for token ${token.tokenId}');
      }

      final txnId = (lockInfo['txn_id'] ?? '').toString();
      if (txnId != bundle.txnId) {
        _log('txn_id mismatch tokenId=${token.tokenId}, tokenTxn=$txnId, expected=${bundle.txnId}');
        throw TokenLockException('txn_id mismatch for token ${token.tokenId}');
      }

      final lockedTo = (lockInfo['locked_to'] ?? '').toString();
      if (lockedTo != myPubKey) {
        _log('locked_to mismatch tokenId=${token.tokenId}');
        throw TokenLockException('Token belongs to another receiver: ${token.tokenId}');
      }

      selected.add(token);
    }

    if (selected.length < bundle.unlockKeys.length) {
      _log('Locked token count < unlock key count. locked=${selected.length}, keys=${bundle.unlockKeys.length}');
      throw const TokenLockException('Missing tokens for unlock bundle');
    }

    // Backward compatible matching: validate each unlock key maps to one locked token via lock_hash.
    final usedIndexes = <int>{};
    for (final entry in bundle.unlockKeys.entries) {
      final unlockKeyHash = _sha256Hex(entry.value);
      var matchIndex = -1;
      for (var i = 0; i < selected.length; i++) {
        if (usedIndexes.contains(i)) continue;
        final lockInfo = selected[i].mutable['lock_info'];
        if (lockInfo is! Map) continue;
        final lockHash = (lockInfo['lock_hash'] ?? '').toString();
        if (lockHash == unlockKeyHash) {
          matchIndex = i;
          break;
        }
      }

      if (matchIndex < 0) {
        _log('No locked token matched unlock key for tokenId=${entry.key}');
        throw TokenLockException('Missing unlockKey target for token ${entry.key}');
      }

      usedIndexes.add(matchIndex);
    }

    _log('All locked token validations passed for txnId=${bundle.txnId}');

    return selected;
  }

  static String _sha256Hex(String input) {
    return sha256.convert(utf8.encode(input)).toString();
  }
}
