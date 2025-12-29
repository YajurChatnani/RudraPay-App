import 'package:flutter/material.dart';
import '../models/recharge_response.dart';
import '../services/storage_service.dart';

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
    // In a real app, fetch current balance from a state management solution
    // For now, we'll use the added amount as the new balance
    _newBalance = widget.addedAmount;
    _saveTokensAndBalance();
  }

  Future<void> _saveTokensAndBalance() async {
    // Save tokens to storage
    await StorageService.saveTokens(widget.response.tokens);

    // Update balance in storage
    final newBalance = await StorageService.addBalance(widget.response.totalTokens);

    // Save total tokens received
    final currentTotal = await StorageService.getTotalTokensReceived();
    await StorageService.saveTotalTokensReceived(
      currentTotal + widget.response.totalTokens,
    );

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
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              '/',
                              (route) => false,
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
