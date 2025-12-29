import 'package:flutter/material.dart';

class TransferPendingScreen extends StatefulWidget {
  const TransferPendingScreen({super.key});

  @override
  State<TransferPendingScreen> createState() =>
      _TransferPendingScreenState();
}

class _TransferPendingScreenState extends State<TransferPendingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                            color: Colors.white.withOpacity(opacity),
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
              const Text(
                'Please wait',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white54,
                ),
              ),

              const SizedBox(height: 48),

              // ---------------- CONTINUE (TESTING) ----------------
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/transaction/result',
                    );
                  },
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
