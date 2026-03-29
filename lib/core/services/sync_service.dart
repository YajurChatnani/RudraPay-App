import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'token_service.dart';
import '../../features/balance/services/transaction_storage_service.dart';
import '../../features/balance/services/storage_service.dart';
import '../../features/balance/models/recharge_response.dart';

class SyncService {
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
    
    try {
      // Get JWT token
      final token = await TokenService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Not authenticated. Please log in.');
      }

      // Get all unsettled transactions
      unsettledTransactions = await TransactionStorageService.getUnsettledTransactions();
      
      if (unsettledTransactions.isEmpty) {
        // Nothing to sync
        return true;
      }

      // Prepare request body
      final requestBody = {
        'transactions': unsettledTransactions,
      };

      _log('[SYNC] Starting transaction sync');

      // Make API request
      final response = await http.post(
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
            final reconciledCount = await _reconcileWithServer(unsettledTransactions);
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
            await _settleTransactions(unsettledTransactions);
            
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
        final reconciledCount = await _reconcileWithServer(unsettledTransactions);
        if (reconciledCount > 0) {
          _log('[SYNC] Reconciliation fallback succeeded');
          return true; // Partial success is still success
        }
      } catch (reconcileError) {
        _log('[SYNC] Reconciliation fallback failed');
      }
      
      rethrow;
    }
  }

  /// Check server for already-synced transactions and reconcile locally
  static Future<int> _reconcileWithServer(List<Map<String, dynamic>> unsettledTransactions) async {
    try {
      final token = await TokenService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Not authenticated');
      }

      // Get all transactions from server
      final response = await http.get(
        Uri.parse('$_baseUrl/api/transactions'),
        headers: {
          'x-auth-token': token,
        },
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Server check timed out');
        },
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
        await _settleTransactions(alreadySynced);
        
        return alreadySynced.length;
      }

      return 0;
    } catch (e) {
      _log('[SYNC] Reconciliation failed');
      rethrow;
    }
  }

  /// Settle transactions locally after successful server sync
  static Future<void> _settleTransactions(List<Map<String, dynamic>> transactions) async {
    _log('[SYNC] Settling local transactions');

    // Get locked tokens once (there's only one lock at a time)
    final lockedData = await StorageService.getLockedTokens();
    bool tokensSettled = false;

    for (final txn in transactions) {
      try {
        final txnId = txn['txnId'] as String;
        final amount = txn['amount'] as int;
        final type = txn['type'] as String;

        if (type == 'credit') {
          // Receiver: check if tokens are locked for this transaction
          if (!tokensSettled && lockedData != null && lockedData['txnId'] == txnId) {
            // This transaction has locked tokens, unlock and add them
            final tokensList = lockedData['tokens'] as List;
            final tokens = tokensList.map((t) => Token.fromJson(t as Map<String, dynamic>)).toList();
            
            await StorageService.unlockTokens();
            await StorageService.addTokens(tokens);
            tokensSettled = true;
            _log('[SYNC] Settled credit transaction');
          } else {
            _log('[SYNC] Credit transaction did not require token settlement');
          }
        } else if (type == 'debit') {
          // Sender: check if tokens are locked for this transaction
          if (!tokensSettled && lockedData != null && lockedData['txnId'] == txnId) {
            // Just unlock (tokens already removed from available)
            await StorageService.unlockTokens();
            tokensSettled = true;
            _log('[SYNC] Settled debit transaction');
          } else {
            _log('[SYNC] Debit transaction did not require token settlement');
          }
        }

        // Move from unsettled to settled list
        await TransactionStorageService.moveToSettled(txnId);
        _log('[SYNC] Moved transaction to settled state');
        
      } catch (e) {
        _log('[SYNC] Failed to settle one transaction');
        // Continue with other transactions
      }
    }

    _log('[SYNC] Settlement complete');
  }
}
