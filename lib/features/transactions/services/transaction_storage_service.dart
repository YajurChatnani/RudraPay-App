// Purpose: Stores and retrieves local transaction records with settled/unsettled status.
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../../core/services/token_service.dart';

/// Lightweight in-memory transaction log used when full storage is unavailable.
class TransactionStorageService {
  static final Map<String, List<Map<String, dynamic>>> _unsettled = {};
  static final Map<String, List<Map<String, dynamic>>> _settled = {};

  static void _log(String message) {
    if (kDebugMode) {
      debugPrint('[TXN-STORAGE] $message');
    }
  }

  static Future<String> _getUserId() async {
    final start = DateTime.now();
    final user = await TokenService.getUser();
    final elapsed = DateTime.now().difference(start).inMilliseconds;
    _log('_getUserId took ${elapsed}ms');
    return user?.id ?? 'guest';
  }

  static String generateTxnId({
    required String senderName,
    required String receiverName,
    required int amount,
    required String timestamp,
    required List<dynamic> tokenIds,
  }) {
    final suffix = Random().nextInt(999999).toString().padLeft(6, '0');
    return 'TXN-$suffix';
  }

  static Future<void> saveUnsettledTransaction({
    required String txnId,
    required int amount,
    required String type,
    required String merchant,
    required String timestamp,
  }) async {
    final start = DateTime.now();
    final userId = await _getUserId();
    _unsettled.putIfAbsent(userId, () => []);
    _unsettled[userId]!.removeWhere((t) => t['txnId'] == txnId);
    _unsettled[userId]!.add({
      'txnId': txnId,
      'amount': amount,
      'type': type,
      'merchant': merchant,
      'timestamp': timestamp,
    });
    _log('saveUnsettledTransaction txnId=$txnId took ${DateTime.now().difference(start).inMilliseconds}ms');
  }

  static Future<void> removeUnsettledTransaction(String txnId) async {
    final start = DateTime.now();
    final userId = await _getUserId();
    _unsettled[userId]?.removeWhere((t) => t['txnId'] == txnId);
    _log('removeUnsettledTransaction txnId=$txnId took ${DateTime.now().difference(start).inMilliseconds}ms');
  }

  static Future<List<Map<String, dynamic>>> getUnsettledTransactions() async {
    final start = DateTime.now();
    final userId = await _getUserId();
    final result = List<Map<String, dynamic>>.unmodifiable(_unsettled[userId] ?? []);
    _log('getUnsettledTransactions count=${result.length} took ${DateTime.now().difference(start).inMilliseconds}ms');
    return result;
  }

  static Future<List<Map<String, dynamic>>> getSettledTransactions() async {
    final start = DateTime.now();
    final userId = await _getUserId();
    final result = List<Map<String, dynamic>>.unmodifiable(_settled[userId] ?? []);
    _log('getSettledTransactions count=${result.length} took ${DateTime.now().difference(start).inMilliseconds}ms');
    return result;
  }

  static Future<void> moveToSettled(String txnId) async {
    final start = DateTime.now();
    final userId = await _getUserId();
    _unsettled.putIfAbsent(userId, () => []);
    _settled.putIfAbsent(userId, () => []);
    
    final txn = _unsettled[userId]!.firstWhere(
      (t) => t['txnId'] == txnId,
      orElse: () => <String, dynamic>{},
    );
    if (txn.isNotEmpty) {
      _unsettled[userId]!.removeWhere((t) => t['txnId'] == txnId);
      _settled[userId]!.insert(0, {...txn, 'settledAt': DateTime.now().toIso8601String()});
    }
    _log('moveToSettled txnId=$txnId took ${DateTime.now().difference(start).inMilliseconds}ms');
  }

  /// Save a transaction directly as settled (for server-added balance)
  static Future<void> saveSettledTransaction({
    required String txnId,
    required int amount,
    required String type,
    required String merchant,
    required String timestamp,
  }) async {
    final start = DateTime.now();
    final userId = await _getUserId();
    _settled.putIfAbsent(userId, () => []);
    
    // Remove if exists (avoid duplicates)
    _settled[userId]!.removeWhere((t) => t['txnId'] == txnId);
    
    // Add as settled transaction
    _settled[userId]!.insert(0, {
      'txnId': txnId,
      'amount': amount,
      'type': type,
      'merchant': merchant,
      'timestamp': timestamp,
      'settledAt': DateTime.now().toIso8601String(),
    });
    _log('saveSettledTransaction txnId=$txnId took ${DateTime.now().difference(start).inMilliseconds}ms');
  }
}
