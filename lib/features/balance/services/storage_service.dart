// Purpose: Secure wallet storage for balance, tokens, limits, and token lock lifecycle.
import 'dart:convert';
import '../models/recharge_response.dart';
import '../../../core/services/token_service.dart';
import '../../../core/services/secure_storage_service.dart';

class StorageService {
  static const String _balanceKey = 'wallet_balance';
  static const String _tokensKey = 'wallet_tokens';
  static const String _tokenIndexKey = 'wallet_token_index';
  static const String _tokenItemPrefix = 'wallet_token';
  static const String _lockedTokensKey = 'locked_tokens';
  static const String _totalTokensKey = 'total_tokens_received';
  static const String _freeTokensUsedKey = 'free_tokens_used';
  static const int _maxFreeTokens = 500;

  /// Get user-scoped storage key
  static Future<String> _getUserKey(String baseKey) async {
    final user = await TokenService.getUser();
    final userId = user?.id ?? 'guest';
    return '${userId}_$baseKey';
  }

  static String _tokenStorageKey(String tokenId) => '${_tokenItemPrefix}_$tokenId';

  static Future<List<String>> _getTokenIds() async {
    final key = await _getUserKey(_tokenIndexKey);
    final raw = await SecureStorageService.getString(key);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveTokenIds(List<String> tokenIds) async {
    final key = await _getUserKey(_tokenIndexKey);
    await SecureStorageService.setString(key, jsonEncode(tokenIds));
  }

  /// Get current balance from storage
  static Future<int> getBalance() async {
    try {
      final key = await _getUserKey(_balanceKey);
      return await SecureStorageService.getInt(key) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Save balance to storage
  static Future<bool> saveBalance(int balance) async {
    try {
      final key = await _getUserKey(_balanceKey);
      await SecureStorageService.setInt(key, balance);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Add amount to existing balance
  static Future<int> addBalance(int amount) async {
    try {
      final currentBalance = await getBalance();
      final newBalance = currentBalance + amount;
      await saveBalance(newBalance);
      return newBalance;
    } catch (e) {
      return 0;
    }
  }

  /// Deduct amount from balance
  static Future<int> deductBalance(int amount) async {
    try {
      final currentBalance = await getBalance();
      final newBalance = currentBalance - amount;
      if (newBalance < 0) {
        return currentBalance; // Don't allow negative balance
      }
      await saveBalance(newBalance);
      return newBalance;
    } catch (e) {
      return 0;
    }
  }

  /// Save tokens to storage
  static Future<bool> saveTokens(List<Token> tokens) async {
    try {
      // Store each token in a separate encrypted record for compartmentalization.
      final previousIds = await _getTokenIds();
      final nextIds = tokens.map((t) => t.tokenId).toSet().toList();

      for (final token in tokens) {
        final itemKey = await _getUserKey(_tokenStorageKey(token.tokenId));
        await SecureStorageService.setString(itemKey, jsonEncode(token.toJson()));
      }

      // Remove token records that are no longer part of the wallet state.
      final removedIds = previousIds.where((id) => !nextIds.contains(id));
      for (final tokenId in removedIds) {
        final itemKey = await _getUserKey(_tokenStorageKey(tokenId));
        await SecureStorageService.remove(itemKey);
      }

      await _saveTokenIds(nextIds);

      // Keep legacy aggregate key in sync for backward compatibility while migrating.
      final legacyKey = await _getUserKey(_tokensKey);
      final legacyList = tokens.map((token) => token.toJson()).toList();
      await SecureStorageService.setString(legacyKey, jsonEncode(legacyList));

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get all tokens from storage
  static Future<List<Token>> getTokens() async {
    try {
      // Preferred path: read token index, then fetch each token record separately.
      final tokenIds = await _getTokenIds();
      if (tokenIds.isNotEmpty) {
        final tokens = <Token>[];
        final validIds = <String>[];

        for (final tokenId in tokenIds) {
          final itemKey = await _getUserKey(_tokenStorageKey(tokenId));
          final raw = await SecureStorageService.getString(itemKey);
          if (raw == null || raw.isEmpty) {
            continue;
          }
          try {
            final map = jsonDecode(raw) as Map<String, dynamic>;
            final token = Token.fromJson(map);
            if (token.tokenId.isNotEmpty) {
              tokens.add(token);
              validIds.add(token.tokenId);
            }
          } catch (_) {
            // Skip malformed token record and continue loading remaining ones.
          }
        }

        // Compact index if some token records were missing/corrupted.
        if (validIds.length != tokenIds.length) {
          await _saveTokenIds(validIds);
        }

        return tokens;
      }

      // Fallback path for legacy storage where tokens were a single JSON array.
      final legacyKey = await _getUserKey(_tokensKey);
      final jsonString = await SecureStorageService.getString(legacyKey);
      if (jsonString == null || jsonString.isEmpty) return [];

      final List<dynamic> jsonList = jsonDecode(jsonString);
      final tokens = jsonList
          .map((item) => Token.fromJson(item as Map<String, dynamic>))
          .where((t) => t.tokenId.isNotEmpty)
          .toList();

      // Migrate legacy aggregate format into per-token encrypted records.
      await saveTokens(tokens);
      return tokens;
    } catch (e) {
      return [];
    }
  }

  /// Save total tokens received count
  static Future<bool> saveTotalTokensReceived(int total) async {
    try {
      final key = await _getUserKey(_totalTokensKey);
      await SecureStorageService.setInt(key, total);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get total tokens received count
  static Future<int> getTotalTokensReceived() async {
    try {
      final key = await _getUserKey(_totalTokensKey);
      return await SecureStorageService.getInt(key) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Clear all wallet data
  static Future<bool> clearWalletData() async {
    try {
      await SecureStorageService.remove(await _getUserKey(_balanceKey));
      await SecureStorageService.remove(await _getUserKey(_tokensKey));
      final tokenIds = await _getTokenIds();
      for (final tokenId in tokenIds) {
        await SecureStorageService.remove(await _getUserKey(_tokenStorageKey(tokenId)));
      }
      await SecureStorageService.remove(await _getUserKey(_tokenIndexKey));
      await SecureStorageService.remove(await _getUserKey(_totalTokensKey));
      await SecureStorageService.remove(await _getUserKey(_freeTokensUsedKey));
      await SecureStorageService.remove(await _getUserKey(_lockedTokensKey));
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get free tokens used count
  static Future<int> getFreeTokensUsed() async {
    try {
      final key = await _getUserKey(_freeTokensUsedKey);
      return await SecureStorageService.getInt(key) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Get remaining free tokens
  static Future<int> getRemainingFreeTokens() async {
    try {
      final used = await getFreeTokensUsed();
      return _maxFreeTokens - used;
    } catch (e) {
      return _maxFreeTokens;
    }
  }

  /// Check if free tokens are exhausted
  static Future<bool> areFreeTokensExhausted() async {
    try {
      final remaining = await getRemainingFreeTokens();
      return remaining <= 0;
    } catch (e) {
      return false;
    }
  }

  /// Add used free tokens and return remaining
  static Future<int> addUsedFreeTokens(int amount) async {
    try {
      final currentUsed = await getFreeTokensUsed();
      final newUsed = currentUsed + amount;

      // Cap at max free tokens
      final finalUsed = newUsed > _maxFreeTokens ? _maxFreeTokens : newUsed;

      final key = await _getUserKey(_freeTokensUsedKey);
      await SecureStorageService.setInt(key, finalUsed);

      return _maxFreeTokens - finalUsed;
    } catch (e) {
      return _maxFreeTokens;
    }
  }

  /// Get unused tokens sorted by creation date (oldest first)
  static Future<List<Token>> getUnusedTokens(int count) async {
    try {
      final allTokens = await getTokens();
      final unusedTokens = allTokens.where((t) => !t.used).toList();
      
      // Sort by createdAt (oldest first)
      unusedTokens.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      
      // Return requested count
      return unusedTokens.take(count).toList();
    } catch (e) {
      print('[STORAGE] Error getting unused tokens: $e');
      return [];
    }
  }

  /// Lock tokens for transfer (mark them as pending)
  static Future<bool> lockTokens(String txnId, List<Token> tokens) async {
    try {
      final key = await _getUserKey(_lockedTokensKey);
      final lockedData = {
        'txnId': txnId,
        'tokens': tokens.map((t) => t.toJson()).toList(),
        'lockedAt': DateTime.now().toIso8601String(),
      };
      await SecureStorageService.setString(key, jsonEncode(lockedData));
      return true;
    } catch (e) {
      print('[STORAGE] Error locking tokens: $e');
      return false;
    }
  }

  /// Unlock tokens (remove lock after failed transfer)
  static Future<bool> unlockTokens() async {
    try {
      final key = await _getUserKey(_lockedTokensKey);
      await SecureStorageService.remove(key);
      return true;
    } catch (e) {
      print('[STORAGE] Error unlocking tokens: $e');
      return false;
    }
  }

  /// Get locked tokens for a transaction
  static Future<Map<String, dynamic>?> getLockedTokens() async {
    try {
      final key = await _getUserKey(_lockedTokensKey);
      final jsonString = await SecureStorageService.getString(key);
      if (jsonString == null) return null;
      
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      print('[STORAGE] Error getting locked tokens: $e');
      return null;
    }
  }

  /// Mark all tokens in the locked transaction as SPENT.
  static Future<bool> markLockedTokensAsSpent(String txnId) async {
    try {
      final key = await _getUserKey(_lockedTokensKey);
      final jsonString = await SecureStorageService.getString(key);
      if (jsonString == null || jsonString.isEmpty) return false;

      final lockedData = jsonDecode(jsonString) as Map<String, dynamic>;
      final currentTxnId = (lockedData['txnId'] ?? '').toString();
      if (currentTxnId != txnId) return false;

      final tokensRaw = lockedData['tokens'];
      if (tokensRaw is! List) return false;

      final updatedTokens = <Map<String, dynamic>>[];
      for (final raw in tokensRaw) {
        if (raw is! Map) continue;
        final map = Map<String, dynamic>.from(raw);
        final mutable = map['mutable'] is Map
            ? Map<String, dynamic>.from(map['mutable'] as Map)
            : <String, dynamic>{};
        mutable['status'] = 'SPENT';
        map['mutable'] = mutable;
        updatedTokens.add(map);
      }

      lockedData['tokens'] = updatedTokens;
      await SecureStorageService.setString(key, jsonEncode(lockedData));
      return true;
    } catch (e) {
      print('[STORAGE] Error marking locked tokens as spent: $e');
      return false;
    }
  }

  /// Remove tokens from storage (after successful transfer)
  static Future<bool> removeTokens(List<String> tokenIds) async {
    try {
      final allTokens = await getTokens();
      final remainingTokens = allTokens
          .where((t) => !tokenIds.contains(t.tokenId))
          .toList();
      
      await saveTokens(remainingTokens);
      
      // Update balance to match token count
      await saveBalance(remainingTokens.length);
      
      return true;
    } catch (e) {
      print('[STORAGE] Error removing tokens: $e');
      return false;
    }
  }

  /// Add tokens to storage (after receiving)
  static Future<bool> addTokens(List<Token> newTokens) async {
    try {
      final existingTokens = await getTokens();
      final allTokens = [...existingTokens, ...newTokens];
      
      await saveTokens(allTokens);
      
      // Update balance to match token count
      await saveBalance(allTokens.length);
      
      return true;
    } catch (e) {
      print('[STORAGE] Error adding tokens: $e');
      return false;
    }
  }

  /// Add or update token records by token_id without duplicating existing entries.
  static Future<bool> addOrUpdateTokens(List<Token> tokens) async {
    try {
      if (tokens.isEmpty) return true;

      final existing = await getTokens();
      final byId = <String, Token>{};

      for (final token in existing) {
        if (token.tokenId.isNotEmpty) {
          byId[token.tokenId] = token;
        }
      }

      for (final token in tokens) {
        if (token.tokenId.isNotEmpty) {
          byId[token.tokenId] = token;
        }
      }

      final merged = byId.values.toList(growable: false);
      final ok = await saveTokens(merged);
      if (!ok) return false;

      await saveBalance(merged.length);
      return true;
    } catch (e) {
      print('[STORAGE] Error in addOrUpdateTokens: $e');
      return false;
    }
  }

  /// Fast path for appending brand-new tokens without scanning the entire wallet.
  /// This is intended for recharge flows where tokens are newly minted.
  static Future<int> appendTokensFast(List<Token> tokens) async {
    try {
      if (tokens.isEmpty) {
        return await getBalance();
      }

      final existingIds = await _getTokenIds();
      final nextIds = <String>{...existingIds};
      var appendedCount = 0;

      for (final token in tokens) {
        final tokenId = token.tokenId;
        if (tokenId.isEmpty || nextIds.contains(tokenId)) {
          continue;
        }

        final itemKey = await _getUserKey(_tokenStorageKey(tokenId));
        await SecureStorageService.setString(itemKey, jsonEncode(token.toJson()));
        nextIds.add(tokenId);
        appendedCount++;
      }

      await _saveTokenIds(nextIds.toList(growable: false));

      final currentBalance = await getBalance();
      final nextBalance = currentBalance + appendedCount;
      await saveBalance(nextBalance);

      return nextBalance;
    } catch (e) {
      print('[STORAGE] Error in appendTokensFast: $e');
      return await getBalance();
    }
  }

  /// Fast path for updating already-known token records without loading the wallet.
  /// This is intended for unlock flows where the token ids already exist locally.
  static Future<bool> overwriteTokensFast(List<Token> tokens) async {
    try {
      if (tokens.isEmpty) return true;

      for (final token in tokens) {
        final tokenId = token.tokenId;
        if (tokenId.isEmpty) {
          continue;
        }

        final itemKey = await _getUserKey(_tokenStorageKey(tokenId));
        await SecureStorageService.setString(itemKey, jsonEncode(token.toJson()));
      }

      final existingIds = await _getTokenIds();
      final nextIds = <String>{...existingIds};
      for (final token in tokens) {
        if (token.tokenId.isNotEmpty) {
          nextIds.add(token.tokenId);
        }
      }
      await _saveTokenIds(nextIds.toList(growable: false));

      return true;
    } catch (e) {
      print('[STORAGE] Error in overwriteTokensFast: $e');
      return false;
    }
  }

  /// Get all locally stored LOCKED tokens for a specific transaction id.
  static Future<List<Token>> getTokensByTxnId(String txnId) async {
    try {
      final expectedTxnId = txnId.trim();
      if (expectedTxnId.isEmpty) return [];

      final allTokens = await getTokens();
      final matches = <Token>[];

      for (final token in allTokens) {
        final mutable = token.mutable;
        final status = (mutable['status'] ?? '').toString().toUpperCase();

        final lockInfo = mutable['lock_info'];
        if (lockInfo is! Map) {
          continue;
        }

        // Support both txn_id and txnId lock-info shapes.
        final currentTxnId = (lockInfo['txn_id'] ?? lockInfo['txnId'] ?? '')
            .toString()
            .trim();

        final isTxnMatch = currentTxnId == expectedTxnId;
        final isLocked = status == 'LOCKED';

        // Primary rule remains LOCKED + txn match.
        // Fallback allows recovery from stale/legacy status while lock_info still exists.
        if (isTxnMatch && (isLocked || status.isEmpty)) {
          matches.add(token);
        }
      }

      print('[STORAGE] getTokensByTxnId expected=$expectedTxnId total=${allTokens.length} matched=${matches.length}');
      return matches;
    } catch (e) {
      print('[STORAGE] Error getting tokens by txnId: $e');
      return [];
    }
  }
}
