import 'package:flutter/material.dart';
import 'dart:math';

class TransactionsListScreen extends StatelessWidget {
  const TransactionsListScreen({super.key});

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
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _MonthCard(
                    month: 'December 2025',
                    items: [
                      TransactionItem(
                        name: 'CafeX Store',
                        initials: 'CS',
                        amount: '-₹320',
                        date: 'Dec 24',
                        status: 'PENDING SETTLEMENT',
                        pending: true,
                      ),
                      TransactionItem(
                        name: 'Priya Sharma',
                        initials: 'PS',
                        amount: '+₹500',
                        date: 'Dec 23',
                        status: 'SETTLED',
                        pending: false,
                      ),
                      TransactionItem(
                        name: 'Aman Verma',
                        initials: 'AV',
                        amount: '-₹150',
                        date: 'Dec 22',
                        status: 'PENDING SETTLEMENT',
                        pending: true,
                      ),
                      TransactionItem(
                        name: 'Wallet Top-up',
                        initials: 'WB',
                        amount: '+₹2,000',
                        date: 'Dec 20',
                        status: 'SETTLED',
                        pending: false,
                      ),
                      TransactionItem(
                        name: 'Local Store',
                        initials: 'LS',
                        amount: '-₹780',
                        date: 'Dec 18',
                        status: 'SETTLED',
                        pending: false,
                      ),
                      TransactionItem(
                        name: 'Rahul Mehta',
                        initials: 'RM',
                        amount: '+₹1,200',
                        date: 'Dec 15',
                        status: 'SETTLED',
                        pending: false,
                      ),
                      TransactionItem(
                        name: 'Metro Tickets',
                        initials: 'MT',
                        amount: '-₹80',
                        date: 'Dec 13',
                        status: 'SETTLED',
                        pending: false,
                      ),
                      TransactionItem(
                        name: 'Online Refund',
                        initials: 'OR',
                        amount: '+₹450',
                        date: 'Dec 12',
                        status: 'SETTLED',
                        pending: false,
                      ),
                      TransactionItem(
                        name: 'Grocer Mart',
                        initials: 'GM',
                        amount: '-₹640',
                        date: 'Dec 10',
                        status: 'PENDING SETTLEMENT',
                        pending: true,
                      ),
                      TransactionItem(
                        name: 'Movie Tickets',
                        initials: 'MV',
                        amount: '-₹520',
                        date: 'Dec 08',
                        status: 'SETTLED',
                        pending: false,
                      ),
                      TransactionItem(
                        name: 'Cashback Credit',
                        initials: 'CB',
                        amount: '+₹120',
                        date: 'Dec 06',
                        status: 'SETTLED',
                        pending: false,
                      ),
                      TransactionItem(
                        name: 'Zara Outlet',
                        initials: 'ZO',
                        amount: '-₹1,450',
                        date: 'Dec 05',
                        status: 'PENDING SETTLEMENT',
                        pending: true,
                      ),
                      TransactionItem(
                        name: 'Pharmacy',
                        initials: 'PH',
                        amount: '-₹230',
                        date: 'Dec 03',
                        status: 'SETTLED',
                        pending: false,
                      ),
                    ],
                  ),
                  _MonthCard(
                    month: 'November 2025',
                    items: [
                      TransactionItem(
                        name: 'Fuel Station',
                        initials: 'FS',
                        amount: '-₹1,120',
                        date: 'Nov 29',
                        status: 'SETTLED',
                        pending: false,
                      ),
                      TransactionItem(
                        name: 'Freelance Payout',
                        initials: 'FP',
                        amount: '+₹9,500',
                        date: 'Nov 28',
                        status: 'SETTLED',
                        pending: false,
                      ),
                      TransactionItem(
                        name: 'Utility Bill',
                        initials: 'UB',
                        amount: '-₹980',
                        date: 'Nov 25',
                        status: 'SETTLED',
                        pending: false,
                      ),
                      TransactionItem(
                        name: 'Gym Membership',
                        initials: 'GY',
                        amount: '-₹1,800',
                        date: 'Nov 20',
                        status: 'PENDING SETTLEMENT',
                        pending: true,
                      ),
                      TransactionItem(
                        name: 'Rohan Patil',
                        initials: 'RP',
                        amount: '+₹600',
                        date: 'Nov 18',
                        status: 'SETTLED',
                        pending: false,
                      ),
                      TransactionItem(
                        name: 'Book Store',
                        initials: 'BS',
                        amount: '-₹340',
                        date: 'Nov 15',
                        status: 'SETTLED',
                        pending: false,
                      ),
                      TransactionItem(
                        name: 'Coffee Bar',
                        initials: 'CB',
                        amount: '-₹210',
                        date: 'Nov 12',
                        status: 'SETTLED',
                        pending: false,
                      ),
                      TransactionItem(
                        name: 'Wallet Top-up',
                        initials: 'WT',
                        amount: '+₹1,500',
                        date: 'Nov 10',
                        status: 'SETTLED',
                        pending: false,
                      ),
                      TransactionItem(
                        name: 'Airport Cab',
                        initials: 'AC',
                        amount: '-₹760',
                        date: 'Nov 08',
                        status: 'SETTLED',
                        pending: false,
                      ),
                      TransactionItem(
                        name: 'Concert Tickets',
                        initials: 'CT',
                        amount: '-₹2,400',
                        date: 'Nov 03',
                        status: 'PENDING SETTLEMENT',
                        pending: true,
                      ),
                    ],
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

// =======================================================
// MONTH CARD
// =======================================================

class _MonthCard extends StatelessWidget {
  final String month;
  final List<TransactionItem> items;

  const _MonthCard({
    required this.month,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
            child: Text(
              month,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ...items,
        ],
      ),
    );
  }
}

// =======================================================
// TRANSACTION ITEM (MATCHES YOUR UI)
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
