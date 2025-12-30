import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../balance/services/storage_service.dart';
import '../../balance/services/transaction_storage_service.dart';
import '../../../core/services/classic_bluetooth_service.dart';
import '../../../core/services/token_service.dart';

class EnterAmountScreen extends StatefulWidget {
  const EnterAmountScreen({super.key});

  @override
  State<EnterAmountScreen> createState() => _EnterAmountScreenState();
}

class _EnterAmountScreenState extends State<EnterAmountScreen> {
  final TextEditingController _controller = TextEditingController(text: '0');
  final ClassicBluetoothService _classicService = ClassicBluetoothService();

  int _availableBalance = 0;
  String _deviceName = 'Unknown Device';
  String _userName = 'User';
  int? _connectionHandle;
  String? _connectionAddress;
  bool _isSending = false;

  int get amount => int.tryParse(_controller.text.replaceAll(RegExp(r'\D'), '')) ?? 0;

  @override
  void initState() {
    super.initState();
    // Wait for the first frame so ModalRoute.of(context) is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    setState(() {
      _deviceName = args?['deviceName'] ?? args?['connectionAddress'] ?? 'Unknown Device';
      _userName = args?['userName'] ?? 'User';
      _connectionHandle = args?['connectionHandle'] as int?;
      _connectionAddress = args?['connectionAddress'] as String?;
    });

    final balance = await StorageService.getBalance();
    if (mounted) {
      setState(() {
        _availableBalance = balance;
      });
    }
  }

  Future<void> _sendPayment() async {
    if (_connectionHandle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No connection handle, reconnect and try again')),
      );
      return;
    }

    final amt = amount;
    if (amt <= 0) return;

    // Check if sufficient balance
    if (amt > _availableBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Insufficient balance. You have $_availableBalance tokens.')),
      );
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      print('[ENTER-AMOUNT] Starting token transfer: $amt tokens');
      
      // Get user info
      final user = await TokenService.getUser();
      final senderName = user?.name ?? _userName;
      
      // Select tokens (oldest first, unused only)
      final tokensToSend = await StorageService.getUnusedTokens(amt);
      
      if (tokensToSend.length < amt) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Insufficient unused tokens. Found ${tokensToSend.length}, need $amt')),
          );
        }
        setState(() => _isSending = false);
        return;
      }

      // Generate transaction ID
      final timestamp = DateTime.now().toIso8601String();
      final tokenIds = tokensToSend.map((t) => t.tokenId).toList();
      final txnId = TransactionStorageService.generateTxnId(
        senderName: senderName,
        receiverName: _deviceName,
        amount: amt,
        timestamp: timestamp,
        tokenIds: tokenIds,
      );

      print('[ENTER-AMOUNT] Generated txnId: $txnId');

      // Lock tokens for transfer
      await StorageService.lockTokens(txnId, tokensToSend);
      print('[ENTER-AMOUNT] Locked $amt tokens');

      // Save as unsettled transaction (debit for sender)
      await TransactionStorageService.saveUnsettledTransaction(
        txnId: txnId,
        amount: amt,
        type: 'debit',
        merchant: _deviceName,
        timestamp: timestamp,
      );
      print('[ENTER-AMOUNT] Saved unsettled transaction');

      // Prepare payment request message
      final paymentRequest = {
        'type': 'payment_request',
        'txnId': txnId,
        'amount': amt,
        'senderName': senderName,
        'timestamp': timestamp,
      };

      // Send payment request
      print('[ENTER-AMOUNT] Sending payment request...');
      await _classicService.sendBytes(
        _connectionHandle!,
        Uint8List.fromList(utf8.encode(jsonEncode(paymentRequest))),
      );
      print('[ENTER-AMOUNT] Payment request sent');

      if (mounted) {
        // Navigate to pending screen with txnId and tokens
        Navigator.pushNamed(context, '/pay/pending', arguments: {
          'amount': amt,
          'deviceName': _deviceName,
          'connectionHandle': _connectionHandle,
          'connectionAddress': _connectionAddress,
          'txnId': txnId,
          'tokens': tokensToSend.map((t) => t.toJson()).toList(),
          'timestamp': timestamp,
        });
      }
    } catch (e) {
      print('[ENTER-AMOUNT] Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Send failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            // ===== SCROLLABLE TOP SECTION =====
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Text(
                          '← Back',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),

                    const Divider(color: Colors.white12),

                    // Paying to
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PAYING TO',
                            style: TextStyle(
                              fontSize: 12,
                              letterSpacing: 1.2,
                              color: Colors.white38,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _deviceName,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Via Bluetooth',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Divider(color: Colors.white12),

                    // Amount
                    const SizedBox(height: 96),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: _controller,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 64,
                            fontWeight: FontWeight.w300,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(border: InputBorder.none),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Tokens',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 96),
                  ],
                ),
              ),
            ),

            // ===== FIXED BOTTOM SECTION =====
            Container(
              color: const Color(0xFF0B0B0B),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(color: Colors.white12),

                  // Paying from
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Paying from', style: TextStyle(color: Colors.white54)),
                            Text('Wallet balance ($_userName)', style: const TextStyle(fontWeight: FontWeight.w500)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Available', style: TextStyle(color: Colors.white54)),
                            Text('$_availableBalance Tokens', style: const TextStyle(fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),
                  const Center(
                    child: Text(
                      'Payment will be settled later',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white38,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Slide to pay
                  Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset + 16),
                    child: _SlideToPay(
                      enabled: amount > 0 && !_isSending && amount <= _availableBalance,
                      label: _isSending
                          ? 'Sending...'
                          : amount > _availableBalance
                              ? 'Insufficient balance ($_availableBalance tokens available)'
                              : amount > 0
                                  ? 'Slide to pay $amount Tokens'
                                  : 'Enter amount to pay',
                      onConfirmed: amount > 0 && !_isSending && amount <= _availableBalance ? _sendPayment : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= SLIDE TO PAY =================

class _SlideToPay extends StatefulWidget {
  final bool enabled;
  final String label;
  final VoidCallback? onConfirmed;

  const _SlideToPay({
    required this.enabled,
    required this.label,
    required this.onConfirmed,
  });

  @override
  State<_SlideToPay> createState() => _SlideToPayState();
}

class _SlideToPayState extends State<_SlideToPay>
    with SingleTickerProviderStateMixin {
  late AnimationController _resetController;
  late Animation<double> _resetAnim;
  double _thumbX = 0.0; // 0..1
  bool _confirmed = false;

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _resetAnim = CurvedAnimation(
      parent: _resetController,
      curve: Curves.easeOut,
    )..addListener(() {
        setState(() {
          _thumbX = _thumbX * (1.0 - _resetAnim.value);
        });
      });
  }

  @override
  void dispose() {
    _resetController.dispose();
    super.dispose();
  }

  void _onPanUpdate(double dx, double max) {
    if (!widget.enabled || _confirmed) return;
    final next = ((_thumbX * max) + dx).clamp(0.0, max) / max;
    setState(() => _thumbX = next);
  }

  void _onPanEnd() {
    if (!widget.enabled || _confirmed) return;
    if (_thumbX > 0.88) {
      setState(() => _confirmed = true);
      widget.onConfirmed?.call();
      // Keep thumb at end visually; no reset here.
    } else {
      _resetController.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF18A561);
    final bgColor = widget.enabled ? accent : accent.withValues(alpha: 0.35);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = 56.0;
        final padding = 2.0; // keep low to fit larger arrows
        final trackRadius = height / 2;
        final thumbSize = height - padding * 2;
        final maxTravel = width - padding * 2 - thumbSize;
        final thumbLeft = padding + maxTravel * _thumbX;
        final fillWidth = thumbLeft + thumbSize * 0.6;
        const Color thumbColor = Colors.white;

        final leftArrowColor = accent.withValues(alpha: 0.65);
        final rightArrowColor = accent;

        return Container(
          height: height,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(trackRadius),
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                width: fillWidth.clamp(thumbSize, width),
                height: height,
                decoration: BoxDecoration(
                  color: widget.enabled
                      ? accent
                      : accent.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(trackRadius),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: widget.enabled ? Colors.white : Colors.white54,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: thumbLeft,
                top: padding,
                child: GestureDetector(
                  onPanUpdate: (details) => _onPanUpdate(details.delta.dx, maxTravel),
                  onPanEnd: (_) => _onPanEnd(),
                  child: Container(
                    height: thumbSize,
                    width: thumbSize,
                    decoration: BoxDecoration(
                      color: thumbColor,
                      shape: BoxShape.circle,
                      boxShadow: widget.enabled
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Transform.translate(
                            offset: const Offset(10, 0),
                            child: Icon(
                              Icons.chevron_right,
                              size: 64,
                              color: leftArrowColor,
                            ),
                          ),
                          Transform.translate(
                            offset: const Offset(-18, 0),
                            child: Icon(
                              Icons.chevron_right,
                              size: 64,
                              color: rightArrowColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
