import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recharge_response.dart';

class StorageService {
  static const String _balanceKey = 'wallet_balance';
  static const String _tokensKey = 'wallet_tokens';
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
}
