import 'package:flutter/material.dart';
import 'dart:math';
import '../../balance/services/transaction_storage_service.dart';

class TransactionsListScreen extends StatefulWidget {
  const TransactionsListScreen({super.key});

  @override
  State<TransactionsListScreen> createState() => _TransactionsListScreenState();
}

class _TransactionsListScreenState extends State<TransactionsListScreen> {
  List<Map<String, dynamic>> _transactions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    try {
      final unsettled = await TransactionStorageService.getUnsettledTransactions();
      setState(() {
        _transactions = unsettled;
        _loading = false;
      });
    } catch (e) {
      print('[TRANSACTIONS] Error loading: $e');
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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

            // ---------------- TITLE ----------------
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(
                'ALL TRANSACTIONS',
                style: TextStyle(
                  fontSize: 13,
                  letterSpacing: 1,
                  color: Colors.white54,
                ),
              ),
            ),

            // ---------------- LIST ----------------
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFE8FF3C),
                        strokeWidth: 2,
                      ),
                    )
                  : _transactions.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Text(
                              'No transactions yet',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _transactions.length,
                          itemBuilder: (context, index) {
                            final txn = _transactions[index];
                            final merchant = txn['merchant'] as String? ?? 'Unknown';
                            final amount = txn['amount'] as int? ?? 0;
                            final type = txn['type'] as String? ?? 'debit';
                            final timestamp = txn['timestamp'] as String? ?? '';
                            final isCredit = type == 'credit';

                            // Format date
                            String dateStr = 'Just now';
                            try {
                              final dt = DateTime.parse(timestamp);
                              dateStr = '${_monthName(dt.month)} ${dt.day}';
                            } catch (e) {
                              // Keep default
                            }

                            return TransactionItem(
                              name: merchant,
                              initials: _getInitials(merchant),
                              amount: '${isCredit ? '+' : '-'}$amount',
                              date: dateStr,
                              status: 'PENDING SETTLEMENT',
                              pending: true,
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '??';
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  String _monthName(int month) {
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month];
  }
}

// =======================================================
// TRANSACTION ITEM (MATCHES YOUR UI)
// =======================================================
// TRANSACTION ITEM
// =======================================================

class TransactionItem extends StatelessWidget {
  final String name;
  final String initials;
  final String amount;
  final String date;
  final String status;
  final bool pending;

  const TransactionItem({
    super.key,
    required this.name,
    required this.initials,
    required this.amount,
    required this.date,
    required this.status,
    required this.pending,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.pushNamed(
          context,
          '/transaction/detail',
          arguments: {
            'name': name,
            'initials': initials,
            'amount': amount,
            'date': date,
            'status': status,
            'pending': pending,
            'tx_id': 'TXN-2512-${DateTime.now().millisecond % 1000}',
            'sender_id': 'Alice Johnson',
            'receiver_id': name,
            'tokens_id': 'TKN-${Random().nextInt(9999).toString().padLeft(4, '0')}',
            'created': '$date • 3:45 PM',
          },
        );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        child: Column(
          children: [
            Row(
              children: [
                // -------- AVATAR --------
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFF2A2A2A),
                  child: Text(
                    initials,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // -------- NAME + META --------
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            date,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white54,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (pending)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: const Color(0xFFE8FF3C).withOpacity(0.14),
                                border: Border.all(
                                  color: const Color(0xFFE8FF3C).withOpacity(0.35),
                                ),
                              ),
                              child: const Icon(
                                Icons.schedule,
                                size: 14,
                                color: Color(0xFFE8FF3C),
                                semanticLabel: 'Pending settlement',
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // -------- AMOUNT --------
                Builder(
                  builder: (_) {
                    final trimmed = amount.trim();
                    final raw = trimmed.replaceFirst(RegExp(r'^[+-]'), '');
                    final isCredit = amount.trim().startsWith('+');
                    final sign = isCredit ? '+' : '-';
                    final display = '$sign$raw';

                    return Text(
                      display,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isCredit ? Colors.greenAccent : Colors.white,
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(color: Colors.white12, height: 1),
          ],
        ),
      ),
    );
  }
}
