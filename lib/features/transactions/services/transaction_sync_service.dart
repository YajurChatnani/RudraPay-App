// Purpose: Syncs unsettled transactions with server and reconciles local settlement state.
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/services/token_service.dart';
import '../../../core/utils/async_timing.dart';
import '../../balance/services/storage_service.dart';
import 'transaction_storage_service.dart';

class TransactionSyncService {
  static const String _baseUrl = 'https://wallet-api-77kp.onrender.com';

  static void _log(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  /// Sync all unsettled transactions with the server
  /// Returns true if successful, throws exception on failure
  static Future<bool> syncTransactions() async {
    List<Map<String, dynamic>> unsettledTransactions = [];
    final totalStart = DateTime.now();
    
    try {
      // Get JWT token
      final token = await traceAwait('[SYNC] TokenService.getToken', TokenService.getToken());
      if (token == null || token.isEmpty) {
        throw Exception('Not authenticated. Please log in.');
      }

      // Get all unsettled transactions
      unsettledTransactions = await traceAwait(
        '[SYNC] TransactionStorageService.getUnsettledTransactions',
        TransactionStorageService.getUnsettledTransactions(),
      );
      _log('[SYNC] Loaded ${unsettledTransactions.length} unsettled txns');
      
      if (unsettledTransactions.isEmpty) {
        // Nothing to sync
        _log('[SYNC] No unsettled transactions to sync');
        return true;
      }

      // Prepare request body
      final requestBody = {
        'transactions': unsettledTransactions,
      };

      _log('[SYNC] Starting transaction sync');

      // Make API request
      final response = await traceAwait(
        '[SYNC] http.post /api/transactions/sync',
        http.post(
          Uri.parse('$_baseUrl/api/transactions/sync'),
          headers: {
            'Content-Type': 'application/json',
            'x-auth-token': token,
          },
          body: jsonEncode(requestBody),
        ).timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw Exception('Sync request timed out. Please check your internet connection.');
          },
        ),
      );

      _log('[SYNC] Server response status received');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        final success = responseData['success'] as bool? ?? false;
        final msg = responseData['msg'] as String? ?? '';
        final syncedCount = responseData['syncedCount'] as int?;

        if (success) {
          // Check if server says transactions were already synced
          if (msg.contains('already synced') || syncedCount == null) {
            _log('[SYNC] Server indicates already-synced state, reconciling');
            // Run reconciliation to settle locally
            final reconciledCount = await traceAwait(
              '[SYNC] _reconcileWithServer',
              _reconcileWithServer(unsettledTransactions),
            );
            if (reconciledCount > 0) {
              _log('[SYNC] Reconciliation succeeded');
              return true;
            } else {
              // If reconciliation finds nothing, it means transactions are truly not synced yet
              throw Exception('Sync inconclusive: ${msg.isNotEmpty ? msg : 'Please try again'}');
            }
          } else if (syncedCount == unsettledTransactions.length) {
            // All transactions synced successfully
            _log('[SYNC] Sync succeeded');
            
            // Settle all transactions
            await traceAwait(
              '[SYNC] _settleTransactions',
              _settleTransactions(unsettledTransactions),
            );
            
            return true;
          } else {
            // Partial failure - treat as full failure
            throw Exception('Partial sync failure: only $syncedCount of ${unsettledTransactions.length} synced');
          }
        } else {
          throw Exception('Sync failed: ${responseData['message'] ?? msg}');
        }
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please log in again.');
      } else if (response.statusCode == 400) {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception('Bad request: ${errorData['message'] ?? 'Invalid data'}');
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      _log('[SYNC] Sync failed');
      
      // Fallback: Check if transactions were already synced on server
      try {
        _log('[SYNC] Attempting reconciliation fallback');
        final reconciledCount = await traceAwait(
          '[SYNC] reconciliation fallback via _reconcileWithServer',
          _reconcileWithServer(unsettledTransactions),
        );
        if (reconciledCount > 0) {
          _log('[SYNC] Reconciliation fallback succeeded');
          return true; // Partial success is still success
        }
      } catch (reconcileError) {
        _log('[SYNC] Reconciliation fallback failed');
      }
      

      _log('[SYNC] syncTransactions total took ${DateTime.now().difference(totalStart).inMilliseconds}ms');
      rethrow;
    }
  }

  /// Check server for already-synced transactions and reconcile locally
  static Future<int> _reconcileWithServer(List<Map<String, dynamic>> unsettledTransactions) async {
    try {
      final start = DateTime.now();
      final token = await traceAwait('[SYNC] TokenService.getToken (reconcile)', TokenService.getToken());
      if (token == null || token.isEmpty) {
        throw Exception('Not authenticated');
      }

      // Get all transactions from server
      final response = await traceAwait(
        '[SYNC] http.get /api/transactions',
        http.get(
          Uri.parse('$_baseUrl/api/transactions'),
          headers: {
            'x-auth-token': token,
          },
        ).timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            throw Exception('Server check timed out');
          },
        ),
      );

      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}');
      }

      final responseData = jsonDecode(response.body) as Map<String, dynamic>;
      final success = responseData['success'] as bool? ?? false;
      
      if (!success) {
        throw Exception('Server check failed');
      }

      final serverTransactions = responseData['transactions'] as List? ?? [];
      final serverTxnIds = serverTransactions.map((t) => t['txnId'] as String).toSet();

      // Find unsettled transactions that are already on server
      final alreadySynced = unsettledTransactions.where((txn) {
        return serverTxnIds.contains(txn['txnId'] as String);
      }).toList();

      if (alreadySynced.isNotEmpty) {
        _log('[SYNC] Found already-synced transactions on server');
        
        // Settle these transactions locally
        await traceAwait(
          '[SYNC] _settleTransactions (already synced)',
          _settleTransactions(alreadySynced),
        );
        
        _log('[SYNC] _reconcileWithServer total took ${DateTime.now().difference(start).inMilliseconds}ms');
        return alreadySynced.length;
      }

      _log('[SYNC] _reconcileWithServer total took ${DateTime.now().difference(start).inMilliseconds}ms');
      return 0;
    } catch (e) {
      _log('[SYNC] Reconciliation failed');
      rethrow;
    }
  }

  /// Settle transactions locally after successful server sync
  static Future<void> _settleTransactions(List<Map<String, dynamic>> transactions) async {
    _log('[SYNC] Settling local transactions');
    final start = DateTime.now();

    // Get locked tokens once (there's only one lock at a time)
    final lockedData = await traceAwait('[SYNC] StorageService.getLockedTokens', StorageService.getLockedTokens());
    bool tokensSettled = false;

    for (final txn in transactions) {
      try {
        final txnId = txn['txnId'] as String;
        final type = txn['type'] as String;

        if (type == 'credit') {
          // Receiver unlock is now QR-driven and persisted during local unlock flow.
          _log('[SYNC] Credit transaction settlement handled by QR unlock flow');
        } else if (type == 'debit') {
          // Sender: check if tokens are locked for this transaction
          if (!tokensSettled && lockedData != null && lockedData['txnId'] == txnId) {
            // Just unlock (tokens already removed from available)
            await traceAwait('[SYNC] StorageService.unlockTokens', StorageService.unlockTokens());
            tokensSettled = true;
            _log('[SYNC] Settled debit transaction');
          } else {
            _log('[SYNC] Debit transaction did not require token settlement');
          }
        }

        // Move from unsettled to settled list
        await traceAwait('[SYNC] TransactionStorageService.moveToSettled txnId=$txnId', TransactionStorageService.moveToSettled(txnId));
        _log('[SYNC] Moved transaction to settled state');
        
      } catch (e) {
        _log('[SYNC] Failed to settle one transaction');
        // Continue with other transactions
      }
    }

    _log('[SYNC] _settleTransactions total took ${DateTime.now().difference(start).inMilliseconds}ms');
    _log('[SYNC] Settlement complete');
  }
}
