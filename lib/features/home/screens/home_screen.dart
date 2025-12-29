import 'package:flutter/material.dart';
import '../../balance/services/storage_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showNotifications = false;
  int _balance = 0;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    final balance = await StorageService.getBalance();
    setState(() {
      _balance = balance;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: const Color(0xFF0B0B0B),
        child: Stack(
          children: [
            // 🌈 Ambient top-left glow (very wide)
            Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.8, -0.9), // slightly off-screen top-left
                  radius: 2.2,
                  colors: [
                    Color(0x2EE8FF3C), // soft yellow-green wash
                    Color(0x00000000),
                  ],
                  stops: [0.0, 1.0],
                ),
              ),
            ),

            // 🌑 Bottom vignette (keeps bottom dark)
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
              child: Stack(
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _profileHeader(context),
                        const SizedBox(height: 24),
                        _balanceCard(),
                        const SizedBox(height: 24),
                        _actionButtons(context),
                        const SizedBox(height: 20),
                        _statusSection(),
                        const SizedBox(height: 24),
                        _transactionsSection(context),
                      ],
                    ),
                  ),
                  if (_showNotifications)
                    Positioned(
                      top: 50,
                      right: 16,
                      child: _notificationPopup(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),

    );
  }

  // ---------------- PROFILE HEADER ----------------

  Widget _profileHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        InkWell(
          onTap: () => Navigator.pushNamed(context, '/profile'),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 22,
                backgroundColor: Color(0xFFE8FF3C),
                child: Text(
                  'YC',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Yajur Chatnani',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'WLT...92KD',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.notifications_none),
          onPressed: () {
            setState(() {
              _showNotifications = !_showNotifications;
            });
          },
        ),
      ],
    );
  }

  // ---------- NOTIFICATION POPUP ----------

  Widget _notificationPopup() {
    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: const Color(0xFF0B0B0B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8FF3C).withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Notifications',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFE8FF3C),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showNotifications = false;
                    });
                  },
                  child: const Icon(
                    Icons.close,
                    size: 18,
                    color: Colors.white38,
                  ),
                ),
              ],
            ),
          ),
          Divider(
            color: const Color(0xFFE8FF3C).withOpacity(0.1),
            height: 1,
            thickness: 1,
          ),
          SizedBox(
            height: 240,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _notificationItem(
                  title: 'Payment Received',
                  message: 'Received ₹500 from Rahul',
                  time: '2 min ago',
                  icon: Icons.check_circle,
                  iconColor: Colors.green,
                ),
                Divider(
                  color: const Color(0xFFE8FF3C).withOpacity(0.05),
                  height: 1,
                  thickness: 1,
                ),
                _notificationItem(
                  title: 'Payment Sent',
                  message: 'Sent ₹1,200 to Priya',
                  time: '15 min ago',
                  icon: Icons.arrow_upward,
                  iconColor: const Color(0xFFE8FF3C),
                ),
                Divider(
                  color: const Color(0xFFE8FF3C).withOpacity(0.05),
                  height: 1,
                  thickness: 1,
                ),
                _notificationItem(
                  title: 'Low Balance Alert',
                  message: 'Your balance is below ₹1,000',
                  time: '1 hour ago',
                  icon: Icons.warning,
                  iconColor: Colors.orange,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _notificationItem({
    required String title,
    required String message,
    required String time,
    required IconData icon,
    required Color iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: iconColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white54,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white38,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- BALANCE CARD ----------------

  Widget _balanceCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFFFFFFFF).withOpacity(0.08),
        border: Border.all(
          color: const Color(0xFFFFFFFF).withOpacity(0.15),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'Balance',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${_balance.toString()}',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------- ACTION BUTTONS ----------------

  Widget _actionButtons(BuildContext context) {
    return Row(
      children: [
        _actionButton(
          label: 'Pay',
          icon: Icons.arrow_upward,
          primary: true,
          onTap: () => Navigator.pushNamed(context, '/pay'),
        ),
        _actionButton(
          label: 'Receive',
          icon: Icons.arrow_downward,
          onTap: () => Navigator.pushNamed(context, '/receive'),
        ),
        _actionButton(
          label: 'Add Balance',
          icon: Icons.add,
          onTap: () => Navigator.pushNamed(context, '/add-balance'),
        ),
      ],
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool primary = false,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              color: primary
                  ? const Color(0xFFE8FF3C)
                  : const Color(0xFFFFFFFF).withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: primary
                  ? null
                  : Border.all(
                      color: const Color(0xFFFFFFFF).withOpacity(0.15),
                      width: 0.5,
                    ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: primary ? Colors.black : Colors.white,
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: primary ? Colors.black : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- STATUS ----------------

  Widget _statusSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'STATUS',
          style: TextStyle(
            color: Colors.white38,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _statusCard('Pending', '2', 'Settling'),
            const SizedBox(width: 12),
            _statusCard(
              'Incoming',
              '₹1,200',
              'Awaiting',
              highlight: true,
            ),
          ],
        ),
      ],
    );
  }

  Widget _statusCard(
      String title,
      String value,
      String note, {
        bool highlight = false,
      }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: highlight
              ? const Color(0xFFE8FF3C).withOpacity(0.15)
              : const Color(0xFFFFFFFF).withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: highlight
                ? const Color(0xFFE8FF3C).withOpacity(0.4)
                : const Color(0xFFFFFFFF).withOpacity(0.15),
            width: highlight ? 1.0 : 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white54)),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(note, style: const TextStyle(color: Colors.white38)),
          ],
        ),
      ),
    );
  }

  // ---------------- TRANSACTIONS ----------------

  Widget _transactionsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'TRANSACTIONS',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/transactions'),
              child: const Text(
                'See All',
                style: TextStyle(color: Color(0xFFE8FF3C)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF).withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFFFFFFF).withOpacity(0.15),
              width: 0.5,
            ),
          ),
          child: Column(
            children: [
              _transactionItem(
                'CafeX Store',
                'Dec 25, 2:30 PM',
                '₹450',
                negative: true,
              ),
              Container(
                height: 1,
                color: const Color(0xFF2A2A2A),
              ),
              _transactionItem(
                'Priya Sharma',
                'Dec 24, 8:45 AM',
                '+₹1,200',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _transactionItem(
      String name,
      String time,
      String amount, {
        bool negative = false,
      }) {
    final initials = name.split(' ').take(2).map((e) => e[0]).join().toUpperCase();
    final Color avatarColor = negative ? const Color(0xFFFF6B6B) : const Color(0xFF4ECDC4);
    
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: avatarColor,
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
