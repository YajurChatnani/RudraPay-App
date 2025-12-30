import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../core/services/classic_bluetooth_service.dart';
import '../../balance/services/storage_service.dart';
import '../../balance/services/transaction_storage_service.dart';
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
  List<Token>? _tokens;
  String? _receiverName;
  String _status = 'Waiting for receiver to respond...';
  
  // Message reassembly buffer (for handling fragmented messages)
  final StringBuffer _messageBuffer = StringBuffer();

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
        print('[PAY-PENDING] Received chunk: $decodedChunk');
        
        _messageBuffer.write(decodedChunk);
        final bufferedMessage = _messageBuffer.toString();
        
        // Check if we have a complete JSON message
        if (_isCompleteMessage(bufferedMessage)) {
          print('[PAY-PENDING] Complete message assembled');
          
          try {
            final decoded = jsonDecode(bufferedMessage) as Map<String, dynamic>;
            _messageBuffer.clear(); // Clear buffer after successful decode
            
            print('[PAY-PENDING] Got response: $decoded');
            
            if (decoded['type'] == 'payment_response') {
              final accepted = decoded['status'] == 'accepted';
              
              if (accepted) {
                // Receiver accepted - now send the actual tokens
                print('[PAY-PENDING] Receiver accepted, sending tokens...');
                setState(() {
                  _status = 'Sending tokens...';
                });
                
                await _sendTokens();
              } else {
                // Receiver rejected - unlock tokens and revert
                print('[PAY-PENDING] Receiver rejected, reverting...');
                await _revertTransaction();
                
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
        } else if (decoded['type'] == 'transfer_complete') {
          // Receiver confirmed token receipt and verification
          print('[PAY-PENDING] Transfer complete, finalizing...');
          await _finalizeTransaction();
          
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
        } else if (decoded['type'] == 'transfer_cancelled_ack') {
          // Receiver acknowledged our cancellation
          print('[PAY-PENDING] Receiver acknowledged cancellation');
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
            print('[PAY-PENDING] Failed to parse complete message: $e');
            _messageBuffer.clear(); // Clear on decode error
          }
        } else {
          print('[PAY-PENDING] Partial message, waiting for more data... Buffer size: ${bufferedMessage.length}');
        }
      } catch (e) {
        print('[PAY-PENDING] Failed to process chunk: $e');
      }
    }, onError: (error) async {
      if (_completed) return;
      print('[PAY-PENDING] Stream error: $error');
      
      // Revert transaction on connection error
      await _revertTransaction();
      
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

      // Prepare token transfer payload
      final tokenTransfer = {
        'type': 'token_transfer',
        'txnId': _txnId,
        'amount': _amount,
        'tokens': _tokens!.map((t) => t.toJson()).toList(),
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Send tokens
      print('[PAY-PENDING] Sending ${_tokens!.length} tokens...');
      await _classicService.sendBytes(
        _connectionHandle!,
        Uint8List.fromList(utf8.encode(jsonEncode(tokenTransfer))),
      );
      print('[PAY-PENDING] Tokens sent');
      
      setState(() {
        _status = 'Tokens sent, waiting for confirmation...';
      });
    } catch (e) {
      print('[PAY-PENDING] Error sending tokens: $e');
      await _revertTransaction();
      
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

  Future<void> _finalizeTransaction() async {
    try {
      // Remove tokens from sender storage
      if (_tokens != null) {
        final tokenIds = _tokens!.map((t) => t.tokenId).toList();
        await StorageService.removeTokens(tokenIds);
        print('[PAY-PENDING] Removed ${tokenIds.length} tokens from storage');
      }

      // Unlock (clear lock)
      await StorageService.unlockTokens();
      print('[PAY-PENDING] Unlocked tokens');

      // Transaction remains as unsettled - will be settled when online sync happens
      print('[PAY-PENDING] Transaction finalized successfully');
    } catch (e) {
      print('[PAY-PENDING] Error finalizing transaction: $e');
    }
  }

  Future<void> _revertTransaction() async {
    try {
      // Unlock tokens (make them available again)
      await StorageService.unlockTokens();
      print('[PAY-PENDING] Unlocked tokens');

      // Remove unsettled transaction
      if (_txnId != null) {
        await TransactionStorageService.removeUnsettledTransaction(_txnId!);
        print('[PAY-PENDING] Removed unsettled transaction');
      }

      print('[PAY-PENDING] Transaction reverted');
    } catch (e) {
      print('[PAY-PENDING] Error reverting transaction: $e');
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
    final shouldCancel = await showDialog<bool>(
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
    ) ?? false;

    if (shouldCancel) {
      // Send cancellation message to receiver
      await _sendCancellationMessage();
      
      // Revert transaction
      await _revertTransaction();
      
      // Disconnect
      await _classicService.disconnect();
      
      print('[PAY-PENDING] Transaction cancelled by user');
      
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
      
      print('[PAY-PENDING] Sending cancellation message: $cancelMessage');
      
      await _classicService.sendBytes(
        _connectionHandle!,
        Uint8List.fromList(
          utf8.encode(jsonEncode(cancelMessage)),
        ),
      );
      
      print('[PAY-PENDING] Cancellation message sent');
    } catch (e) {
      print('[PAY-PENDING] Failed to send cancellation message: $e');
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
            ],
          ),
        ),
      ),
      ),
    );
  }
}
