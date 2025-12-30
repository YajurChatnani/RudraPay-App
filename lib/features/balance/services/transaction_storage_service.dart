import 'dart:math';
import '../../../core/services/token_service.dart';

/// Lightweight in-memory transaction log used when full storage is unavailable.
class TransactionStorageService {
  static final Map<String, List<Map<String, dynamic>>> _unsettled = {};
  static final Map<String, List<Map<String, dynamic>>> _settled = {};

  static Future<String> _getUserId() async {
    final user = await TokenService.getUser();
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
  }

  static Future<void> removeUnsettledTransaction(String txnId) async {
    final userId = await _getUserId();
    _unsettled[userId]?.removeWhere((t) => t['txnId'] == txnId);
  }

  static Future<List<Map<String, dynamic>>> getUnsettledTransactions() async {
    final userId = await _getUserId();
    return List<Map<String, dynamic>>.unmodifiable(_unsettled[userId] ?? []);
  }

  static Future<List<Map<String, dynamic>>> getSettledTransactions() async {
    final userId = await _getUserId();
    return List<Map<String, dynamic>>.unmodifiable(_settled[userId] ?? []);
  }

  static Future<void> moveToSettled(String txnId) async {
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
  }

  /// Save a transaction directly as settled (for server-added balance)
  static Future<void> saveSettledTransaction({
    required String txnId,
    required int amount,
    required String type,
    required String merchant,
    required String timestamp,
  }) async {
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
  }
}
