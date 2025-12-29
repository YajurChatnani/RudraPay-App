import 'package:flutter/material.dart';

class PayBluetoothConnectingScreen extends StatefulWidget {
  const PayBluetoothConnectingScreen({super.key});

  @override
  State<PayBluetoothConnectingScreen> createState() =>
      _PayBluetoothConnectingScreenState();
}

class _PayBluetoothConnectingScreenState
    extends State<PayBluetoothConnectingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
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
        child: Stack(
          children: [
            // Ambient background
            Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.8, -0.9),
                  radius: 2.2,
                  colors: [
                    Color(0x2EE8FF3C),
                    Color(0x00000000),
                  ],
                ),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: const [
                              Icon(
                                Icons.arrow_back_ios_new,
                                size: 24,
                                color: Colors.white,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Back',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 80),

                  // Pulse animation
                  SizedBox(
                    height: 160,
                    width: 160,
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (_, __) {
                        return CustomPaint(
                          painter: _PulsePainter(_controller.value),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'Connecting...',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Searching for nearby device',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white54,
                    ),
                  ),

                  const Spacer(),

                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(context, '/pay/connected');
                      },
                      child: Container(
                        height: 56,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white12),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
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
    );
  }
}

// ---------------- PULSE PAINTER ----------------

class _PulsePainter extends CustomPainter {
  final double progress;
  _PulsePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    for (int i = 0; i < 3; i++) {
      final ringProgress = (progress + i * 0.33) % 1.0;
      final radius = lerp(20, maxRadius, ringProgress);
      final opacity = (1 - ringProgress).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = Colors.white.withOpacity(opacity * 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawCircle(center, radius, paint);
    }
  }

  double lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  bool shouldRepaint(_) => true;
}
