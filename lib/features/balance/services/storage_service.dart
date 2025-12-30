import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recharge_response.dart';

class StorageService {
  static const String _balanceKey = 'wallet_balance';
  static const String _tokensKey = 'wallet_tokens';
  static const String _lockedTokensKey = 'locked_tokens';
  static const String _totalTokensKey = 'total_tokens_received';
  static const String _freeTokensUsedKey = 'free_tokens_used';
  static const int _maxFreeTokens = 500;

  /// Get current balance from storage
  static Future<int> getBalance() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_balanceKey) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Save balance to storage
  static Future<bool> saveBalance(int balance) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setInt(_balanceKey, balance);
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
      final prefs = await SharedPreferences.getInstance();
      final tokensList = tokens.map((token) {
        return {
          'tokenId': token.tokenId,
          'value': token.value,
          'used': token.used,
          'signature': token.signature,
          'createdAt': token.createdAt,
        };
      }).toList();
      final jsonString = jsonEncode(tokensList);
      return await prefs.setString(_tokensKey, jsonString);
    } catch (e) {
      return false;
    }
  }

  /// Get all tokens from storage
  static Future<List<Token>> getTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_tokensKey);
      if (jsonString == null) return [];

      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList
          .map((item) => Token.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Save total tokens received count
  static Future<bool> saveTotalTokensReceived(int total) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setInt(_totalTokensKey, total);
    } catch (e) {
      return false;
    }
  }

  /// Get total tokens received count
  static Future<int> getTotalTokensReceived() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_totalTokensKey) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Clear all wallet data
  static Future<bool> clearWalletData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_balanceKey);
      await prefs.remove(_tokensKey);
      await prefs.remove(_totalTokensKey);
      await prefs.remove(_freeTokensUsedKey);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get free tokens used count
  static Future<int> getFreeTokensUsed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_freeTokensUsedKey) ?? 0;
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

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_freeTokensUsedKey, finalUsed);

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
      final prefs = await SharedPreferences.getInstance();
      final lockedData = {
        'txnId': txnId,
        'tokens': tokens.map((t) => t.toJson()).toList(),
        'lockedAt': DateTime.now().toIso8601String(),
      };
      return await prefs.setString(_lockedTokensKey, jsonEncode(lockedData));
    } catch (e) {
      print('[STORAGE] Error locking tokens: $e');
      return false;
    }
  }

  /// Unlock tokens (remove lock after failed transfer)
  static Future<bool> unlockTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_lockedTokensKey);
    } catch (e) {
      print('[STORAGE] Error unlocking tokens: $e');
      return false;
    }
  }

  /// Get locked tokens for a transaction
  static Future<Map<String, dynamic>?> getLockedTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_lockedTokensKey);
      if (jsonString == null) return null;
      
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      print('[STORAGE] Error getting locked tokens: $e');
      return null;
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
}
