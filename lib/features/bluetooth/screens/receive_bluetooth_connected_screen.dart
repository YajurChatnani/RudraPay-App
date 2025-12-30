import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../core/services/classic_bluetooth_service.dart';
import '../../../core/services/token_service.dart';
import '../../balance/services/storage_service.dart';
import '../../balance/services/transaction_storage_service.dart';
import '../../balance/models/recharge_response.dart';

class ReceiveBluetoothConnectedScreen extends StatefulWidget {
  const ReceiveBluetoothConnectedScreen({super.key});

  @override
  State<ReceiveBluetoothConnectedScreen> createState() =>
      _ReceiveBluetoothConnectedScreenState();
}

class _ReceiveBluetoothConnectedScreenState
    extends State<ReceiveBluetoothConnectedScreen> {
  final ClassicBluetoothService _classicService = ClassicBluetoothService();
  
  StreamSubscription? _messageSubscription;
  
  String? _deviceName;
  String? _userName;
  String? _userId;
  
  bool _waitingForPayment = true;
  bool _isProcessing = false;
  int? _connectionHandle;
  Map<String, dynamic>? _incomingRequest;
  String _statusMessage = 'Waiting for payment...';
  bool _didInitRoute = false;
  
  // Message reassembly buffer (for handling fragmented messages)
  final StringBuffer _messageBuffer = StringBuffer();
  
  // Track if tokens were already received (for cancellation after receipt)
  bool _tokensReceived = false;
  String? _receivedTxnId;
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitRoute) return;
    _didInitRoute = true;
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    print('[RECEIVE-CONNECTED] Loading initial data...');
    
    // Get passed arguments (now available after first frame)
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    
    // Get user info
    final user = await TokenService.getUser();

    // Fallback to local device name if none passed
    final fallbackDeviceName = await ClassicBluetoothService.getDeviceName();

    setState(() {
      _deviceName = args?['deviceName'] ?? args?['connectionAddress'] ?? fallbackDeviceName;
      _connectionHandle = args?['connectionHandle'] as int?;
      _userName = user?.name ?? 'User';
      _userId = user?.id.toString() ?? 'unknown';
    });

    print('[RECEIVE-CONNECTED] Device: $_deviceName, User: $_userName, ID: $_userId');

    // Start listening only after handle is known
    if (_connectionHandle != null) {
      _listenForIncomingPayment();
    } else {
      print('[RECEIVE-CONNECTED] No connection handle provided; cannot listen for data');
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

  void _listenForIncomingPayment() {
    print('[RECEIVE-CONNECTED] Listening for incoming payment bytes on handle $_connectionHandle ...');

    _messageSubscription = _classicService
        .listenToBytes(_connectionHandle ?? -1)
        .listen((data) async {
      try {
        // Decode the chunk and add to buffer
        final decodedChunk = utf8.decode(data);
        print('[RECEIVE-CONNECTED] Received chunk: $decodedChunk');
        
        _messageBuffer.write(decodedChunk);
        final bufferedMessage = _messageBuffer.toString();
        
        // Check if we have a complete JSON message
        if (_isCompleteMessage(bufferedMessage)) {
          print('[RECEIVE-CONNECTED] Complete message assembled');
          
          try {
            final decoded = jsonDecode(bufferedMessage) as Map<String, dynamic>;
            
            // Clear buffer after successful decode
            _messageBuffer.clear();
            
            if (decoded['type'] == 'payment_request') {
              // Initial payment request
              setState(() {
                _waitingForPayment = false;
                _incomingRequest = decoded;
                _statusMessage = 'Payment request received';
              });
              _showPaymentRequestDialog(decoded);
            } else if (decoded['type'] == 'token_transfer') {
              // Actual tokens received
              _handleTokenTransfer(decoded);
            } else if (decoded['type'] == 'transfer_cancelled') {
              // Sender cancelled the transfer
              print('[RECEIVE-CONNECTED] Sender cancelled transfer');
              final message = decoded['reason'] as String? ?? 'Sender cancelled transfer';
              
              // Mark as cancelled
              _cancelled = true;
              
              // If tokens were already received, need to revert them
              if (_tokensReceived && _receivedTxnId != null) {
                print('[RECEIVE-CONNECTED] Reverting already-received tokens due to cancellation');
                
                try {
                  // Get the transaction details to know how many tokens to remove
                  final unsettledTxns = await TransactionStorageService.getUnsettledTransactions();
                  final txnToRevert = unsettledTxns.firstWhere(
                    (t) => t['txnId'] == _receivedTxnId,
                    orElse: () => <String, dynamic>{},
                  );
                  
                  if (txnToRevert.isNotEmpty) {
                    final amount = txnToRevert['amount'] as int;
                    
                    // Get current tokens
                    final currentTokens = await StorageService.getTokens();
                    if (currentTokens.length >= amount) {
                      // Remove the last 'amount' tokens (the ones we just added)
                      final tokensToRemove = currentTokens.sublist(currentTokens.length - amount);
                      final tokenIdsToRemove = tokensToRemove.map((t) => t.tokenId).toList();
                      await StorageService.removeTokens(tokenIdsToRemove);
                      print('[RECEIVE-CONNECTED] Reverted $amount tokens');
                    }
                    
                    // Delete the unsettled transaction
                    await TransactionStorageService.removeUnsettledTransaction(_receivedTxnId!);
                    print('[RECEIVE-CONNECTED] Deleted unsettled transaction: $_receivedTxnId');
                  }
                } catch (e) {
                  print('[RECEIVE-CONNECTED ERROR] Failed to revert tokens: $e');
                }
              }
              
              // Send acknowledgment
              try {
                final ackMsg = {
                  'type': 'transfer_cancelled_ack',
                  'txnId': decoded['txnId'],
                  'message': _tokensReceived 
                      ? 'Tokens reverted, cancellation acknowledged'
                      : 'Cancellation acknowledged by receiver',
                  'tokensReverted': _tokensReceived,
                  'timestamp': DateTime.now().toIso8601String(),
                };
                await _classicService.sendBytes(
                  _connectionHandle!,
                  Uint8List.fromList(utf8.encode(jsonEncode(ackMsg))),
                );
                print('[RECEIVE-CONNECTED] Cancellation ack sent (tokens reverted: $_tokensReceived)');
              } catch (e) {
                print('[RECEIVE-CONNECTED] Failed to send ack: $e');
              }
              
              // Disconnect and navigate to fail screen
              await _classicService.disconnect();
              
              if (!mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/transaction/fail',
                (route) => false,
                arguments: {
                  'amount': _incomingRequest?['amount'] ?? 0,
                  'deviceName': _incomingRequest?['senderName'] ?? _deviceName ?? 'Sender',
                  'txnId': decoded['txnId'] ?? 'N/A',
                  'method': 'Bluetooth',
                  'message': _tokensReceived 
                      ? '$message\n\nTokens have been reverted'
                      : message,
                  'isReceiver': true,
                },
              );
            }
          } catch (e) {
            print('[RECEIVE-CONNECTED ERROR] Failed to decode complete message: $e');
            _messageBuffer.clear(); // Clear on decode error to prevent deadlock
          }
        } else {
          print('[RECEIVE-CONNECTED] Partial message, waiting for more data... Buffer size: ${bufferedMessage.length}');
        }
      } catch (e) {
        print('[RECEIVE-CONNECTED ERROR] Failed to process chunk: $e');
      }
    }, onError: (error) {
      print('[RECEIVE-CONNECTED ERROR] Stream error: $error');
      _showError('Connection error: $error');
    }, onDone: () {
      print('[RECEIVE-CONNECTED] Connection closed by sender');
      if (mounted) {
        _showError('Sender disconnected unexpectedly');
        setState(() {
          _statusMessage = 'Connection lost';
        });
      }
    });
  }

  void _showPaymentRequestDialog(Map<String, dynamic> request) {
    final amount = request['amount'] ?? 0;
    final senderName = request['senderName'] ?? 'Unknown';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Payment Request',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$senderName wants to send you',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE8FF3C).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE8FF3C).withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Text(
                    '$amount',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE8FF3C),
                    ),
                  ),
                  const Text(
                    'Tokens',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Transaction ID: ${request['txnId'] ?? 'N/A'}',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _isProcessing ? null : () => _handlePaymentResponse(false, request),
            child: Text(
              'Reject',
              style: TextStyle(
                color: _isProcessing ? Colors.grey : Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: _isProcessing ? null : () => _handlePaymentResponse(true, request),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE8FF3C),
              foregroundColor: Colors.black,
              disabledBackgroundColor: Colors.grey,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isProcessing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                    ),
                  )
                : const Text('Accept', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePaymentResponse(bool accepted, Map<String, dynamic> request) async {
    print('[RECEIVE-CONNECTED] Payment response: ${accepted ? 'ACCEPTED' : 'REJECTED'}');
    
    setState(() {
      _isProcessing = true;
    });

    try {
      if (mounted) {
        // Close dialog
        Navigator.of(context).pop();
      }

      // Send response to sender
      await _sendResponseToSender(
        accepted: accepted,
        request: request,
        message: accepted 
            ? 'Payment accepted, awaiting tokens...' 
            : 'Payment rejected by receiver',
      );

      if (accepted) {
        // Wait for tokens to arrive
        setState(() {
          _statusMessage = 'Waiting for tokens...';
        });
        print('[RECEIVE-CONNECTED] Waiting for token transfer...');
      } else {
        // Show rejection message
        _showInfo('Payment rejected');
        
        await Future.delayed(const Duration(seconds: 2));
        
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/home',
            (route) => false,
          );
        }
      }
    } catch (e) {
      print('[RECEIVE-CONNECTED ERROR] Payment response failed: $e');
      
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        
        _showError('Response failed: $e');
      }
    }
  }

  Future<void> _handleTokenTransfer(Map<String, dynamic> tokenData) async {
    print('[RECEIVE-CONNECTED] Token transfer received');
    
    try {
      final txnId = tokenData['txnId'] as String?;
      final amount = tokenData['amount'] as int?;
      final timestamp = tokenData['timestamp'] as String?;
      final tokensJson = tokenData['tokens'] as List<dynamic>?;

      if (txnId == null || amount == null || tokensJson == null) {
        throw Exception('Invalid token transfer data');
      }

      // Parse tokens
      final tokens = tokensJson
          .map((t) => Token.fromJson(t as Map<String, dynamic>))
          .toList();

      print('[RECEIVE-CONNECTED] Received ${tokens.length} tokens');

      // Verify token count matches amount
      if (tokens.length != amount) {
        throw Exception('Token count mismatch: expected $amount, got ${tokens.length}');
      }

      setState(() {
        _statusMessage = 'Verifying tokens...';
      });

      // Add tokens to storage
      await StorageService.addTokens(tokens);
      print('[RECEIVE-CONNECTED] Added ${tokens.length} tokens to storage');

      // Save as unsettled transaction (credit for receiver)
      await TransactionStorageService.saveUnsettledTransaction(
        txnId: txnId,
        amount: amount,
        type: 'credit',
        merchant: _incomingRequest?['senderName'] ?? _deviceName ?? 'Sender',
        timestamp: timestamp ?? DateTime.now().toIso8601String(),
      );
      print('[RECEIVE-CONNECTED] Saved unsettled transaction');
      
      // Mark tokens as received (for cancellation handling)
      _tokensReceived = true;
      _receivedTxnId = txnId;

      // Send confirmation to sender
      await _sendTransferComplete(txnId);

      setState(() {
        _isProcessing = false;
        _statusMessage = 'Transfer complete!';
      });

      // Check if cancelled before showing success
      if (_cancelled) {
        print('[RECEIVE-CONNECTED] Transfer was cancelled, skipping success navigation');
        return;
      }

      // Navigate to success screen (no delay, immediate navigation)
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/transaction/result',
          (route) => false,
          arguments: {
            'amount': amount,
            'otherPartyName': _incomingRequest?['senderName'] ?? _deviceName ?? 'Sender',
            'txnId': txnId,
            'method': 'Bluetooth',
            'message': 'Payment received successfully',
            'isReceiver': true,
          },
        );
      }
    } catch (e) {
      print('[RECEIVE-CONNECTED ERROR] Token transfer failed: $e');
      
      setState(() {
        _isProcessing = false;
        _statusMessage = 'Transfer failed: $e';
      });
      
      // Send error response
      await _sendTransferError(
        _incomingRequest?['txnId'] as String?,
        'Token verification failed: $e',
      );
      
      _showError('Token transfer failed: $e');
    }
  }

  Future<void> _sendResponseToSender({
    required bool accepted,
    required Map<String, dynamic> request,
    String? message,
  }) async {
    try {
      if (_connectionHandle == null) {
        print('[RECEIVE-CONNECTED] No connection handle, cannot send response');
        return;
      }

      final response = {
        'type': 'payment_response',
        'status': accepted ? 'accepted' : 'rejected',
        'txnId': request['txnId'],
        'amount': request['amount'],
        'receiverName': _userName,
        'message': message,
      };

      print('[RECEIVE-CONNECTED] Sending response: $response');
      await _classicService.sendBytes(
        _connectionHandle!,
        Uint8List.fromList(utf8.encode(jsonEncode(response))),
      );
      print('[RECEIVE-CONNECTED] Response sent');
    } catch (e) {
      print('[RECEIVE-CONNECTED ERROR] Failed to send response: $e');
    }
  }

  Future<void> _sendTransferComplete(String txnId) async {
    try {
      if (_connectionHandle == null) return;

      final confirmation = {
        'type': 'transfer_complete',
        'txnId': txnId,
        'status': 'success',
        'message': 'Tokens received and verified',
      };

      print('[RECEIVE-CONNECTED] Sending transfer complete confirmation');
      await _classicService.sendBytes(
        _connectionHandle!,
        Uint8List.fromList(utf8.encode(jsonEncode(confirmation))),
      );
      print('[RECEIVE-CONNECTED] Confirmation sent');
    } catch (e) {
      print('[RECEIVE-CONNECTED ERROR] Failed to send confirmation: $e');
    }
  }

  Future<void> _sendTransferError(String? txnId, String error) async {
    try {
      if (_connectionHandle == null) return;

      final errorResponse = {
        'type': 'transfer_error',
        'txnId': txnId,
        'status': 'failed',
        'message': error,
      };

      print('[RECEIVE-CONNECTED] Sending transfer error');
      await _classicService.sendBytes(
        _connectionHandle!,
        Uint8List.fromList(utf8.encode(jsonEncode(errorResponse))),
      );
    } catch (e) {
      print('[RECEIVE-CONNECTED ERROR] Failed to send error: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.blue.withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _messageBuffer.clear(); // Clear buffer on dispose
    super.dispose();
  }

  /// Handle back button press during receive
  Future<bool> _onWillPop() async {
    // Show confirmation dialog
    final shouldCancel = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Stop Receiving?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        content: const Text(
          'Leaving will close the connection and cancel any pending transfers.',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Waiting'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Stop Receiving',
              style: TextStyle(color: Color(0xFFE8FF3C)),
            ),
          ),
        ],
      ),
    ) ?? false;

    if (shouldCancel) {
      // Mark as cancelled
      _cancelled = true;
      
      // If we have an incoming request, send cancellation acknowledgment
      if (_incomingRequest != null) {
        await _sendCancellationAcknowledgment();
        
        // Navigate to fail screen with cancellation message
        if (!mounted) return true;
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/transaction/fail',
          (route) => false,
          arguments: {
            'amount': _incomingRequest?['amount'] ?? 0,
            'deviceName': _incomingRequest?['senderName'] ?? _deviceName ?? 'Sender',
            'txnId': _incomingRequest?['txnId'] ?? 'N/A',
            'method': 'Bluetooth',
            'message': 'You cancelled the transfer',
            'isReceiver': true,
          },
        );
      } else {
        // No active transaction, just disconnect
        await _classicService.disconnect();
        print('[RECEIVE-CONNECTED] Stopped receiving by user');
        
        if (!mounted) return true;
        Navigator.pop(context);
      }
      
      // Disconnect
      await _classicService.disconnect();
    }

    return false; // Prevent back navigation if not cancelled
  }

  /// Send acknowledgment for cancellation
  Future<void> _sendCancellationAcknowledgment() async {
    try {
      if (_connectionHandle == null || _incomingRequest?['txnId'] == null) return;
      
      final txnId = _incomingRequest!['txnId'] as String;
      
      final ackMessage = {
        'type': 'transfer_cancelled_ack',
        'txnId': txnId,
        'message': 'Receiver cancelled and closed connection',
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      print('[RECEIVE-CONNECTED] Sending cancellation acknowledgment: $ackMessage');
      
      await _classicService.sendBytes(
        _connectionHandle!,
        Uint8List.fromList(
          utf8.encode(jsonEncode(ackMessage)),
        ),
      );
      
      print('[RECEIVE-CONNECTED] Cancellation acknowledgment sent');
    } catch (e) {
      print('[RECEIVE-CONNECTED] Failed to send cancellation acknowledgment: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: Container(
          color: const Color(0xFF0B0B0B),
          child: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(-0.8, -0.9),
                  radius: 2.2,
                  colors: [Color(0x2EE8FF3C), Color(0x00000000)],
                ),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: _isProcessing ? null : () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.arrow_back_ios_new, size: 24, color: Colors.white),
                              SizedBox(width: 6),
                              Text('Back', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white70)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Connected icon
                            Container(
                              height: 120,
                              width: 120,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8FF3C).withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.bluetooth_connected,
                                size: 60,
                                color: Color(0xFFE8FF3C),
                              ),
                            ),

                            const SizedBox(height: 32),

                            // Status text
                            const Text(
                              'Connected',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Device name
                            Text(
                              _deviceName ?? 'Unknown Device',
                              style: const TextStyle(
                                fontSize: 18,
                                color: Colors.white70,
                              ),
                            ),

                            const SizedBox(height: 48),

                            // Status message
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFFFF).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFFFFFFF).withValues(alpha: 0.15),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_waitingForPayment) ...[
                                    const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Color(0xFFE8FF3C),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                  ],
                                  Text(
                                    _statusMessage,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            if (_incomingRequest != null) ...[
                              const SizedBox(height: 24),
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8FF3C).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFFE8FF3C).withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    const Text(
                                      'Payment Amount',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.white54,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${_incomingRequest!['amount']} Tokens',
                                      style: const TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFE8FF3C),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'From: ${_incomingRequest!['senderName']}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.white54,
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
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
