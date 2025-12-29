import 'package:flutter/material.dart';

class TransactionResultScreen extends StatelessWidget {
  const TransactionResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),
      body: Column(
        children: [
          // ---------------- GREEN HEADER ----------------
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 64, 24, 32),
            decoration: const BoxDecoration(
              color: Color(0xFF1E7F4D), // deep green, not flashy
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            child: Column(
              children: const [
                // Checkmark
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.check,
                    color: Color(0xFF1E7F4D),
                    size: 32,
                  ),
                ),
                SizedBox(height: 16),

                Text(
                  'Payment Sent',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8),

                Text(
                  '₹450',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 6),

                Text(
                  'Pending settlement',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ---------------- DETAILS ----------------
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: const [
                _ResultRow(
                  label: 'Transaction ID',
                  value: 'TXN-2512-449AF',
                  monospace: true,
                ),
                _ResultRow(label: 'Type', value: 'Payment'),
                _ResultRow(label: 'To', value: 'CafeX Store'),
                _ResultRow(label: 'Method', value: 'Bluetooth'),
                _ResultRow(label: 'Time', value: 'Dec 25, 3:45 PM'),
              ],
            ),
          ),

          const Spacer(),

          // ---------------- FOOTER ----------------
          Padding(
            padding: const EdgeInsets.all(24),
            child: GestureDetector(
              onTap: () {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/',
                      (route) => false,
                );
              },
              child: Container(
                height: 56,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Done',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- COMPACT ROW ----------------

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;
  final bool monospace;

  const _ResultRow({
    required this.label,
    required this.value,
    this.monospace = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontFamily: monospace ? 'monospace' : null,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
