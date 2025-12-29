import 'package:flutter/material.dart';

class TransactionDetailScreen extends StatelessWidget {
  const TransactionDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final Map<String, dynamic>? mapArgs = args is Map<String, dynamic> ? args : null;

    // Safe extraction with defaults and sample data
    final String name = (mapArgs?['name'] ?? 'CafeX Store').toString();
    final String amount = (mapArgs?['amount'] ?? '-₹450').toString();
    final String status = (mapArgs?['status'] ?? 'pending').toString();
    final String txId = (mapArgs?['tx_id'] ?? mapArgs?['txnId'] ?? 'TXN-2512-449AF').toString();
    final String senderId = (mapArgs?['sender_id'] ?? 'Yajur Chatnani').toString();
    final String receiverId = (mapArgs?['receiver_id'] ?? 'CafeX Store').toString();
    final String tokenId = (mapArgs?['tokens_id'] ?? 'TKN-7834').toString();
    final String created = (mapArgs?['created'] ?? 'Dec 24, 2025 • 3:45 PM').toString();

    final trimmed = amount.trim();
    final raw = trimmed.replaceAll(RegExp(r'[^0-9.]'), '').trim();
    final isCredit = trimmed.startsWith('+');
    final displayAmount = raw.isEmpty ? '₹0' : '₹$raw';

    final statusLower = status.toLowerCase();
    final isPending = statusLower.contains('pending');
    final isFailed = statusLower.contains('fail');
    final statusColor = isPending
        ? const Color(0xFFE8FF3C)
        : isFailed
            ? Colors.redAccent
            : Colors.white70;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---------------- BACK ----------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: InkWell(
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
            ),

            const SizedBox(height: 8),

            // ---------------- AMOUNT + DATE/TIME + STATUS ----------------
            Center(
              child: Column(
                children: [
                  Text(
                    displayAmount,
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: isCredit ? Colors.greenAccent : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    created,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white54,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: statusColor.withOpacity(0.16),
                      border: Border.all(color: statusColor.withOpacity(0.4)),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 0.4,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ---------------- PERSON CARD ----------------
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF141414),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: const Color(0xFF2A2A2A),
                    child: Text(
                      (mapArgs?['initials'] ?? '?').toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        txId,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ---------------- DETAILS ----------------
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _DetailRow(label: 'Transaction ID', value: txId, mono: true),
                  _DetailRow(label: 'From', value: senderId, mono: true),
                  _DetailRow(label: 'To', value: receiverId, mono: true),
                  _DetailRow(label: 'Token ID', value: tokenId, mono: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =======================================================
// DETAIL ROW
// =======================================================

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool mono;

  const _DetailRow({
    required this.label,
    required this.value,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white54,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              fontFamily: mono ? 'monospace' : null,
            ),
          ),
        ],
      ),
    );
  }
}
