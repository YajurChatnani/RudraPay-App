// Purpose: Shows recharge outcome, persists received tokens, and updates local wallet totals.
import 'package:flutter/material.dart';
import '../models/recharge_response.dart';
import '../services/storage_service.dart';
import '../../../core/utils/async_timing.dart';
import '../../transactions/services/transaction_storage_service.dart';
import '../../../features/home/screens/home_screen.dart';

class RechargeResultScreen extends StatefulWidget {
  final RechargeResponse response;
  final int addedAmount;
  final int remainingTokens;

  const RechargeResultScreen({
    super.key,
    required this.response,
    required this.addedAmount,
    this.remainingTokens = 500,
  });

  @override
  State<RechargeResultScreen> createState() => _RechargeResultScreenState();
}

class _RechargeResultScreenState extends State<RechargeResultScreen> {
  late int _newBalance;

  @override
  void initState() {
    super.initState();
    _newBalance = 0;
    _saveTokensAndBalance();
  }

  Future<void> _saveTokensAndBalance() async {
    // Fast append newly recharged tokens without scanning the entire wallet.
    final newBalance = await traceAwait('[RECHARGE] StorageService.appendTokensFast', StorageService.appendTokensFast(widget.response.tokens));
    if (newBalance < 0) {
      print('[RECHARGE] Failed to persist recharged tokens');
      return;
    }
    print('[RECHARGE] Persisted tokens=${widget.response.tokens.length}, balance=$newBalance');

    // Save total tokens received
    final currentTotal = await traceAwait('[RECHARGE] StorageService.getTotalTokensReceived', StorageService.getTotalTokensReceived());
    await traceAwait('[RECHARGE] StorageService.saveTotalTokensReceived', StorageService.saveTotalTokensReceived(currentTotal + widget.response.totalTokens));

    // Create a settled transaction for server-added balance
    try {
      // Generate transaction ID for this recharge
      final txnId = 'recharge_${DateTime.now().millisecondsSinceEpoch}';
      
      // Save as SETTLED transaction (credit from server, not awaiting settlement)
      await traceAwait(
        '[RECHARGE] TransactionStorageService.saveSettledTransaction',
        TransactionStorageService.saveSettledTransaction(
          txnId: txnId,
          amount: widget.response.totalTokens,
          type: 'credit',
          merchant: 'RudraPay Server',
          timestamp: DateTime.now().toIso8601String(),
        ),
      );
      print('[RECHARGE] Created settled transaction for server balance addition');
    } catch (e) {
      print('[RECHARGE] Error creating transaction: $e');
    }

    // Update the displayed balance
    if (mounted) {
      setState(() {
        _newBalance = newBalance;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: const Color(0xFF0B0B0B),
        child: Stack(
          children: [
            // 🌈 Ambient top-left glow
            Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.8, -0.9),
                  radius: 2.2,
                  colors: [
                    Color(0x2EE8FF3C),
                    Color(0x00000000),
                  ],
                  stops: [0.0, 1.0],
                ),
              ),
            ),

            // 🌑 Bottom vignette
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x000B0B0B),
                    Color(0xFF0B0B0B),
                  ],
                ),
              ),
            ),

            // 👇 Actual content
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Success Icon
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF00C9A7).withValues(alpha: 0.2),
                          border: Border.all(
                            color: const Color(0xFF00C9A7).withValues(alpha: 0.5),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.check_circle,
                          size: 60,
                          color: Color(0xFF00C9A7),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Success Message
                      const Text(
                        'Recharge Successful!',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),

                      Text(
                        widget.response.message,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white54,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 40),

                      // Balance Update Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          color: const Color(0xFFFFFFFF).withValues(alpha: 0.08),
                          border: Border.all(
                            color: const Color(0xFFFFFFFF).withValues(alpha: 0.15),
                            width: 0.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Tokens Received',
                              style: TextStyle(color: Colors.white70),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  '+',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w300,
                                    color: Color(0xFF00C9A7),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${widget.response.totalTokens}',
                                  style: const TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.w300,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Container(
                              height: 1,
                              color: const Color(0xFF2A2A2A),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'New Balance',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white54,
                                  ),
                                ),
                                Text(
                                  '₹$_newBalance',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFE8FF3C),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              height: 1,
                              color: const Color(0xFF2A2A2A),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Remaining Free Tokens',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white54,
                                  ),
                                ),
                                Text(
                                  '${widget.remainingTokens}/500',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: widget.remainingTokens <= 0
                                        ? Colors.red
                                        : const Color(0xFFE8FF3C),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Continue Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => HomeScreen(
                                  initialBalance: _newBalance,
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE8FF3C),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Continue to Home',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
