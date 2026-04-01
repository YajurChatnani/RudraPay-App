// Purpose: Failure-state UI shown when a transaction cannot be completed.
import 'package:flutter/material.dart';

class TransactionFailScreen extends StatelessWidget {
  const TransactionFailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};
    final amount = args['amount'] as int? ?? 0;
    final otherPartyName = args['otherPartyName'] as String? ?? args['deviceName'] as String? ?? 'User';
    final txnId = args['txnId'] as String? ?? 'N/A';
    final method = args['method'] as String? ?? 'Bluetooth';
    final failureReason = args['failureReason'] as String? ?? 'Transaction could not be completed';
    final isReceiver = args['isReceiver'] as bool? ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),
      body: Column(
        children: [
          // ---------------- RED HEADER ----------------
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 64, 24, 32),
            decoration: const BoxDecoration(
              color: Color(0xFFB33B3B), // deep red
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            child: Column(
              children: [
                // Error Icon
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.close,
                    color: Color(0xFFB33B3B),
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  isReceiver ? 'Payment Failed to Receive' : 'Payment Failed',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),

                Text(
                  '₹$amount',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),

                Text(
                  failureReason,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ---------------- DETAILS ----------------
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                _ResultRow(
                  label: 'Transaction ID',
                  value: txnId,
                  monospace: true,
                ),
                _ResultRow(label: 'Type', value: 'Payment'),
                _ResultRow(label: isReceiver ? 'From' : 'To', value: otherPartyName),
                _ResultRow(label: 'Method', value: method),
                _ResultRow(label: 'Status', value: 'Failed'),
              ],
            ),
          ),

          const Spacer(),

          // ---------------- FOOTER ----------------
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Retry Button
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  child: Container(
                    height: 56,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFB33B3B),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'Retry',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Home Button
                GestureDetector(
                  onTap: () {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/home',
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
                      'Back to Home',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
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
