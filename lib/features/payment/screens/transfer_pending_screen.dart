// Purpose: Pending transfer screen that performs Bluetooth exchange and awaits settlement.
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/utils/async_timing.dart';
import '../../bluetooth/services/classic_bluetooth_service.dart';
import '../../balance/services/storage_service.dart';
import '../../balance/services/token_lock_service.dart';
import '../../balance/services/wallet_keypair_service.dart';
import '../../transactions/services/transaction_storage_service.dart';
import '../../balance/models/recharge_response.dart' show Token;

class TransferPendingScreen extends StatefulWidget {
  const TransferPendingScreen({super.key});

  @override
  State<TransferPendingScreen> createState() =>
      _TransferPendingScreenState();
}

class _TransferPendingScreenState extends State<TransferPendingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  final ClassicBluetoothService _classicService = ClassicBluetoothService();
  StreamSubscription? _subscription;
  bool _completed = false;
  int? _connectionHandle;
  String? _deviceName;
  int? _amount;
  String? _txnId;
  String? _qrPayload;
  List<Token>? _tokens;
  String? _receiverName;
  String _status = 'Waiting for receiver to respond...';
  bool _showUnlockQr = false;
  
  // Message reassembly buffer (for handling fragmented messages)
  final StringBuffer _messageBuffer = StringBuffer();

  void _log(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadArgs());
  }

  void _loadArgs() {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    setState(() {
      _connectionHandle = args?['connectionHandle'] as int?;
      _deviceName = args?['deviceName'] as String?;
      _amount = args?['amount'] as int?;
      _txnId = args?['txnId'] as String?;
      _qrPayload = args?['qrPayload'] as String?;
      
      // Parse tokens from JSON
      final tokensJson = args?['tokens'] as List<dynamic>?;
      if (tokensJson != null) {
        _tokens = tokensJson
            .map((t) => Token.fromJson(t as Map<String, dynamic>))
            .toList();
      }
    });

    if (_connectionHandle != null && !_completed) {
      _startListening();
    } else {
      setState(() {
        _status = 'No connection. Please reconnect.';
      });
    }
  }

  /// Check if a complete JSON message is available in the buffer
  bool _isCompleteMessage(String buffer) {
    if (buffer.trim().isEmpty) return false;
    if (!buffer.trim().startsWith('{')) return false;
    
    int braceCount = 0;
    bool inString = false;
    bool escaped = false;
    
    for (int i = 0; i < buffer.length; i++) {
      final char = buffer[i];
      
      if (escaped) {
        escaped = false;
        continue;
      }
      
      if (char == '\\') {
        escaped = true;
        continue;
      }
      
      if (char == '"' && !escaped) {
        inString = !inString;
        continue;
      }
      
      if (!inString) {
        if (char == '{') braceCount++;
        if (char == '}') braceCount--;
      }
    }
    
    return braceCount == 0 && !inString;
  }

  void _startListening() {
    setState(() {
      _status = 'Awaiting receiver confirmation...';
    });

    _subscription = _classicService
        .listenToBytes(_connectionHandle!)
        .listen((data) async {
      if (_completed) return;
      try {
        final decodedChunk = utf8.decode(data);
        _log('[PAY-PENDING] Received bluetooth data chunk');
        
        _messageBuffer.write(decodedChunk);
        final bufferedMessage = _messageBuffer.toString();
        
        // Check if we have a complete JSON message
        if (_isCompleteMessage(bufferedMessage)) {
          _log('[PAY-PENDING] Complete message assembled');
          
          try {
            final decoded = jsonDecode(bufferedMessage) as Map<String, dynamic>;
            _messageBuffer.clear(); // Clear buffer after successful decode
            
            _log('[PAY-PENDING] Received response message');
            
            if (decoded['type'] == 'payment_response') {
              final accepted = decoded['status'] == 'accepted';
              
              if (accepted) {
                // Receiver accepted - extract their public key and re-lock tokens
                _log('[PAY-PENDING] Receiver accepted, extracting receiver pubkey');
                final receiverPubKey = decoded['receiverPubKey'] as String?;
                
                if (receiverPubKey == null || receiverPubKey.isEmpty) {
                  _log('[PAY-PENDING ERROR] Receiver did not provide public key');
                  throw Exception('Receiver public key not received');
                }
                
                _log('[PAY-PENDING] Receiver pubkey received, re-locking tokens with correct pubkey');
                
                // Re-lock tokens with correct receiver public key
                if (_tokens != null && _txnId != null) {
                  try {
                    // First, change tokens back to UNSPENT so they can be re-locked
                    final tokensToRelock = _tokens!.map((token) {
                      final nextMutable = Map<String, dynamic>.from(token.mutable);
                      nextMutable['status'] = 'UNSPENT';
                      nextMutable.remove('lock_info'); // Remove old lock info
                      return Token(
                        immutable: token.immutable,
                        issuer: token.issuer,
                        mutable: nextMutable,
                      );
                    }).toList();

                    // Re-lock with correct receiver public key
                    final senderKeyPair = await traceAwait('[PAY-PENDING] WalletKeyPairService.getOrCreateKeyPair', WalletKeyPairService.getOrCreateKeyPair());
                    final relockResult = TokenLockService.lockTokens(
                      tokens: tokensToRelock,
                      senderPrivKey: senderKeyPair.privateKeyPem,
                      receiverPubKey: receiverPubKey,
                      txnId: _txnId,
                    );
                    
                    _log('[PAY-PENDING] Tokens re-locked with correct receiver pubkey');
                    
                    // Update in-memory tokens and QR payload
                    setState(() {
                      _tokens = relockResult.updatedTokens;
                      _qrPayload = relockResult.transactionBundle.toQrPayloadString();
                    });
                    
                    _log('[PAY-PENDING] Updated tokens and QR payload');
                  } catch (e) {
                    _log('[PAY-PENDING ERROR] Failed to re-lock tokens: $e');
                    throw Exception('Failed to re-lock tokens: $e');
                  }
                }
                
                // Now send the re-locked tokens
                _log('[PAY-PENDING] Sending re-locked tokens');
                setState(() {
                  _status = 'Sending tokens...';
                });
                
                await traceAwait('[PAY-PENDING] _sendTokens', _sendTokens());
              } else {
                // Receiver rejected - unlock tokens and revert
                _log('[PAY-PENDING] Receiver rejected, reverting transaction');
                await traceAwait('[PAY-PENDING] _revertTransaction after reject', _revertTransaction());
                
                _completed = true;
                final message = decoded['message'] as String? ?? 'Payment rejected by receiver';
            
            if (!mounted) return;
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/transaction/fail',
              (route) => false,
              arguments: {
                'amount': _amount ?? 0,
                'otherPartyName': _receiverName ?? _deviceName ?? 'Receiver',
                'txnId': _txnId,
                'method': 'Bluetooth',
                'message': message,
                'isReceiver': false,
              },
            );
          }
        } else if (decoded['type'] == 'token_unlocked' || decoded['type'] == 'transfer_complete') {
          // Receiver confirmed QR scan + unlock (or legacy transfer_complete compatibility)
          _log('[PAY-PENDING] Receiver unlock confirmation received, navigating now and finalizing in background');
          
          _completed = true;
          final message = decoded['message'] as String? ?? 'Transfer successful';
          
          if (!mounted) return;
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/transaction/result',
            (route) => false,
            arguments: {
              'amount': _amount ?? 0,
              'otherPartyName': _receiverName ?? _deviceName ?? 'Receiver',
              'txnId': _txnId,
              'method': 'Bluetooth',
              'message': message,
              'isReceiver': false,
            },
          );

          // Run local cleanup after success UI transition to reduce perceived latency.
          unawaited(
            traceAwait('[PAY-PENDING] _finalizeTransaction background', _finalizeTransaction()),
          );
        } else if (decoded['type'] == 'transfer_cancelled_ack') {
          // Receiver acknowledged our cancellation
          _log('[PAY-PENDING] Receiver acknowledged cancellation');
          _completed = true;
          
          final message = decoded['message'] as String? ?? 'Transaction cancelled';
          
          if (!mounted) return;
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/transaction/fail',
            (route) => false,
            arguments: {
              'amount': _amount ?? 0,
              'otherPartyName': _receiverName ?? _deviceName ?? 'Receiver',
              'txnId': _txnId,
              'method': 'Bluetooth',
              'message': message,
              'isReceiver': false,
            },
          );
        }
          } catch (e) {
            _log('[PAY-PENDING] Failed to parse complete message');
            _messageBuffer.clear(); // Clear on decode error
          }
        } else {
          _log('[PAY-PENDING] Partial message, awaiting more data');
        }
      } catch (e) {
        _log('[PAY-PENDING] Failed to process incoming data chunk');
      }
    }, onError: (error) async {
      if (_completed) return;
      _log('[PAY-PENDING] Stream error occurred');
      
      // Revert transaction on connection error
      await traceAwait('[PAY-PENDING] _revertTransaction after stream error', _revertTransaction());
      
      _completed = true;
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/transaction/fail',
        (route) => false,
        arguments: {
          'amount': _amount ?? 0,
          'deviceName': _deviceName ?? 'Receiver',
          'txnId': _txnId,
          'method': 'Bluetooth',
          'message': 'Connection lost before confirmation',
        },
      );
    });
  }

  Future<void> _sendTokens() async {
    try {
      if (_tokens == null || _connectionHandle == null) {
        throw Exception('Missing tokens or connection handle');
      }

      final transportTokens = _tokens!.map(_normalizeTokenForTransfer).toList(growable: false);

      // Prepare token transfer payload
      final tokenTransfer = {
        'type': 'token_transfer',
        'txnId': _txnId,
        'amount': _amount,
        'tokens': transportTokens.map((t) => t.toJson()).toList(),
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Send tokens
      _log('[PAY-PENDING] Sending token transfer payload');
      await traceAwait(
        '[PAY-PENDING] ClassicBluetoothService.sendBytes token_transfer',
        _classicService.sendBytes(
          _connectionHandle!,
          Uint8List.fromList(utf8.encode(jsonEncode(tokenTransfer))),
        ),
      );

      if (_txnId != null) {
        await traceAwait('[PAY-PENDING] StorageService.markLockedTokensAsSpent', StorageService.markLockedTokensAsSpent(_txnId!));
      }
      _log('[PAY-PENDING] Token transfer payload sent');
      
      setState(() {
        _showUnlockQr = _qrPayload != null && _qrPayload!.isNotEmpty;
        _status = _showUnlockQr
            ? 'Show this QR to receiver to unlock tokens...'
            : 'Tokens sent, waiting for confirmation...';
      });
    } catch (e) {
      _log('[PAY-PENDING] Error sending tokens');
      await traceAwait('[PAY-PENDING] _revertTransaction after send failure', _revertTransaction());
      
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/transaction/fail',
          (route) => false,
          arguments: {
            'amount': _amount ?? 0,
            'deviceName': _deviceName ?? 'Receiver',
            'txnId': _txnId,
            'method': 'Bluetooth',
            'message': 'Failed to send tokens: $e',
          },
        );
      }
    }
  }

  Token _normalizeTokenForTransfer(Token token) {
    if (token.immutable.isNotEmpty) {
      return token;
    }

    final tokenId = token.tokenId;
    final value = token.value;
    final fallbackImmutable = <String, dynamic>{
      'token_id': tokenId,
      'value': value,
      'mint_info': {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'expiry': null,
      },
    };

    _log('[PAY-PENDING] Normalized legacy token payload for transfer tokenId=$tokenId value=$value');
    return Token(
      immutable: fallbackImmutable,
      issuer: Map<String, dynamic>.from(token.issuer),
      mutable: Map<String, dynamic>.from(token.mutable),
    );
  }

  Future<void> _finalizeTransaction() async {
    try {
      // Remove tokens from sender storage
      if (_tokens != null) {
        final tokenIds = _tokens!.map((t) => t.tokenId).toList();
        await traceAwait('[PAY-PENDING] StorageService.removeTokens', StorageService.removeTokens(tokenIds));
        _log('[PAY-PENDING] Updated sender token storage after transfer');
      }

      // Unlock (clear lock)
      await traceAwait('[PAY-PENDING] StorageService.unlockTokens finalize', StorageService.unlockTokens());
      _log('[PAY-PENDING] Token lock released');

      // Transaction remains as unsettled - will be settled when online sync happens
      _log('[PAY-PENDING] Transaction finalized successfully');
    } catch (e) {
      _log('[PAY-PENDING] Error finalizing transaction');
    }
  }

  Future<void> _revertTransaction() async {
    try {
      // Unlock tokens (make them available again)
      await traceAwait('[PAY-PENDING] StorageService.unlockTokens revert', StorageService.unlockTokens());
      _log('[PAY-PENDING] Token lock released');

      // Remove unsettled transaction
      if (_txnId != null) {
        await traceAwait('[PAY-PENDING] TransactionStorageService.removeUnsettledTransaction', TransactionStorageService.removeUnsettledTransaction(_txnId!));
        _log('[PAY-PENDING] Removed unsettled transaction');
      }

      _log('[PAY-PENDING] Transaction reverted');
    } catch (e) {
      _log('[PAY-PENDING] Error reverting transaction');
    }
  }

  /// Handle back button press during transfer
  Future<bool> _onWillPop() async {
    if (_completed) {
      // Block navigation even if completed (will auto-navigate)
      return false;
    }
    
    // Block back button once tokens are being sent
    if (_status.contains('Sending tokens') || _status.contains('Transferring securely')) {
      return false;
    }

    // Show confirmation dialog only during \"Waiting for receiver\" phase
    final shouldCancel = await traceAwait(
      '[PAY-PENDING] showDialog cancel transfer',
      showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Cancel Transfer?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          content: const Text(
            'Cancelling will abort the transfer and notify the receiver.',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep Transferring'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Cancel Transfer',
                style: TextStyle(color: Color(0xFFE8FF3C)),
              ),
            ),
          ],
        ),
      ),
    ) ?? false;

    if (shouldCancel) {
      // Send cancellation message to receiver
      await traceAwait('[PAY-PENDING] _sendCancellationMessage', _sendCancellationMessage());
      
      // Revert transaction
      await traceAwait('[PAY-PENDING] _revertTransaction after cancel', _revertTransaction());
      
      // Disconnect
      await traceAwait('[PAY-PENDING] ClassicBluetoothService.disconnect', _classicService.disconnect());
      
      _log('[PAY-PENDING] Transaction cancelled by user');
      
      if (!mounted) return true;
      
      // Pop back to payment screen
      Navigator.pop(context);
    }

    return false; // Prevent back navigation if not cancelled
  }

  /// Send cancellation message to receiver
  Future<void> _sendCancellationMessage() async {
    try {
      if (_connectionHandle == null || _txnId == null) return;
      
      final cancelMessage = {
        'type': 'transfer_cancelled',
        'txnId': _txnId,
        'reason': 'Sender cancelled transaction',
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      _log('[PAY-PENDING] Sending cancellation message');
      
      await traceAwait(
        '[PAY-PENDING] ClassicBluetoothService.sendBytes transfer_cancelled',
        _classicService.sendBytes(
          _connectionHandle!,
          Uint8List.fromList(
            utf8.encode(jsonEncode(cancelMessage)),
          ),
        ),
      );
      
      _log('[PAY-PENDING] Cancellation message sent');
    } catch (e) {
      _log('[PAY-PENDING] Failed to send cancellation message');
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();

    _messageBuffer.clear(); // Clear buffer on dispose
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: Container(
          color: const Color(0xFF0B0B0B),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ---------------- ANIMATED DOTS ----------------
                SizedBox(
                  height: 40,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (_, __) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(4, (index) {
                          final progress =
                              (_controller.value + index * 0.2) % 1.0;
                          final opacity =
                          (progress < 0.5 ? progress : 1 - progress)
                              .clamp(0.2, 1.0);

                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            height: 10,
                            width: 10,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: opacity),
                              shape: BoxShape.circle,
                            ),
                          );
                        }),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 32),

                // ---------------- TEXT ----------------
                const Text(
                  'Transferring securely…',
                  style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _status,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white54,
                ),
              ),

              if (_showUnlockQr && _qrPayload != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Unlock QR',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      QrImageView(
                        data: _qrPayload!,
                        version: QrVersions.auto,
                        size: 220,
                        backgroundColor: Colors.white,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Txn: ${_txnId ?? '-'}',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      ),
    );
  }
}
