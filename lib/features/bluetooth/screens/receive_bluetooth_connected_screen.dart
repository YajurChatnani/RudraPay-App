import 'package:flutter/material.dart';

class ReceiveBluetoothConnectedScreen extends StatelessWidget {
  const ReceiveBluetoothConnectedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: const Color(0xFF0B0B0B),
        child: Stack(
          children: [
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

                  // Connected indicator (neutral, not celebratory)
                  Container(
                    height: 96,
                    width: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFE8FF3C),
                        width: 3,
                      ),
                    ),
                    child: const Icon(
                      Icons.bluetooth_connected,
                      color: Color(0xFFE8FF3C),
                      size: 40,
                    ),
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'Connected',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'Waiting for payment request',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white54,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Sender info (mock)
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1C),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.person, color: Colors.white54),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Rajesh Kumar',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Passive CTA
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      height: 56,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white12),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'Ready to receive',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
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
