import 'dart:async';
import 'package:flutter/material.dart';
import '../../balance/services/storage_service.dart';
import '../../balance/services/transaction_storage_service.dart';
import '../../../core/services/token_service.dart';
import '../../../core/services/sync_service.dart';
import '../../../core/models/user_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showNotifications = false;
  int _balance = 0;
  User? _user;
  List<Map<String, dynamic>> _recentTransactions = [];
  List<Map<String, dynamic>> _allUnsettledTransactions = [];
  bool _loadingTransactions = true;
  bool _syncing = false;
  DateTime? _lastSyncTime;
  Timer? _syncTimeUpdateTimer;

  @override
  void initState() {
    super.initState();
    _loadBalance();
    _loadUser();
    _loadRecentTransactions();
    _startSyncTimeUpdateTimer();
  }

  @override
  void dispose() {
    _syncTimeUpdateTimer?.cancel();
    super.dispose();
  }

  void _startSyncTimeUpdateTimer() {
    // Update the sync time display every second to keep it current
    _syncTimeUpdateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _lastSyncTime != null) {
        setState(() {
          // Just trigger rebuild to update the time display
        });
      }
    });
  }

  Future<void> _loadBalance() async {
    final balance = await StorageService.getBalance();
    setState(() {
      _balance = balance;
    });
  }

  Future<void> _loadUser() async {
    final user = await TokenService.getUser();
    setState(() {
      _user = user;
    });
  }
  
  Future<void> _loadRecentTransactions() async {
    try {
      final unsettled = await TransactionStorageService.getUnsettledTransactions();
      final settled = await TransactionStorageService.getSettledTransactions();
      
      // Combine and sort by timestamp (most recent first)
      final allTransactions = [...unsettled, ...settled];
      allTransactions.sort((a, b) {
        final aTime = DateTime.tryParse(a['timestamp'] as String? ?? '') ?? DateTime(1970);
        final bTime = DateTime.tryParse(b['timestamp'] as String? ?? '') ?? DateTime(1970);
        return bTime.compareTo(aTime);
      });
      
      setState(() {
        _allUnsettledTransactions = unsettled; // Store ALL unsettled for calculation
        _recentTransactions = allTransactions.take(5).toList(); // Show 5 most recent
        _loadingTransactions = false;
        _lastSyncTime = DateTime.now();
      });
    } catch (e) {
      print('[HOME] Error loading transactions: $e');
      setState(() {
        _loadingTransactions = false;
      });
    }
  }

  Future<void> _handleSync() async {
    if (_syncing) return; // Prevent multiple simultaneous syncs

    setState(() {
      _syncing = true;
    });

    try {
      final success = await SyncService.syncTransactions();
      
      if (success && mounted) {
        // Reload balance and transactions
        await _loadBalance();
        await _loadRecentTransactions();
        
        // Show success toast
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Transactions synced successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('[HOME] Sync error: $e');
      
      // Even if sync failed, still reload in case reconciliation succeeded
      if (mounted) {
        await _loadBalance();
        await _loadRecentTransactions();
      }
      
      if (mounted) {
        // Show error toast
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✗ Sync failed: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _syncing = false;
        });
      }
    }
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '??';
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  String _getShortWalletId() {
    if (_user?.id == null || _user!.id.isEmpty) return 'WLT...XXXX';
    final id = _user!.id;
    if (id.length < 8) return 'WLT...$id';
    return 'WLT...${id.substring(id.length - 4).toUpperCase()}';
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
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFE8FF3C),
                child: Text(
                  _user != null ? _getInitials(_user!.name) : 'U',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _user?.name ?? 'Loading...',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _getShortWalletId(),
                    style: const TextStyle(
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
    // Get recent transactions (max 10 most recent)
    final notifications = _recentTransactions.take(10).toList();
    
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
            child: notifications.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'No notifications yet',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: notifications.length,
                    separatorBuilder: (context, index) => Divider(
                      color: const Color(0xFFE8FF3C).withOpacity(0.05),
                      height: 1,
                      thickness: 1,
                    ),
                    itemBuilder: (context, index) {
                      final txn = notifications[index];
                      final merchant = txn['merchant'] as String? ?? 'Unknown';
                      final amount = txn['amount'] as int? ?? 0;
                      final type = txn['type'] as String? ?? 'debit';
                      final timestamp = txn['timestamp'] as String? ?? '';
                      final isCredit = type == 'credit';
                      final isUnsettled = txn['settledAt'] == null;
                      
                      // Format time
                      String timeStr = 'Just now';
                      try {
                        final dt = DateTime.parse(timestamp);
                        final now = DateTime.now();
                        final diff = now.difference(dt);
                        if (diff.inMinutes < 1) {
                          timeStr = 'Just now';
                        } else if (diff.inHours < 1) {
                          timeStr = '${diff.inMinutes}m ago';
                        } else if (diff.inDays < 1) {
                          timeStr = '${diff.inHours}h ago';
                        } else if (diff.inDays == 1) {
                          timeStr = 'Yesterday';
                        } else if (diff.inDays < 7) {
                          timeStr = '${diff.inDays}d ago';
                        } else {
                          timeStr = '${diff.inDays ~/ 7}w ago';
                        }
                      } catch (e) {
                        // Keep default
                      }
                      
                      final title = isCredit ? 'Payment Received' : 'Payment Sent';
                      final message = isCredit 
                          ? 'Received ₹$amount from $merchant' 
                          : 'Sent ₹$amount to $merchant';
                      final icon = isCredit ? Icons.arrow_downward : Icons.arrow_upward;
                      final iconColor = isCredit ? Colors.green : const Color(0xFFE8FF3C);
                      
                      return _notificationItem(
                        title: title,
                        message: message,
                        time: timeStr,
                        icon: icon,
                        iconColor: iconColor,
                        isUnsettled: isUnsettled,
                      );
                    },
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
    bool isUnsettled = false,
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
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (isUnsettled) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8FF3C).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(
                            color: const Color(0xFFE8FF3C).withOpacity(0.4),
                            width: 0.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.schedule,
                          size: 10,
                          color: Color(0xFFE8FF3C),
                        ),
                      ),
                    ],
                  ],
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
            _statusCard('Awaiting Settlement', '₹${_calculateTotalUnsettled()}', ''),
            const SizedBox(width: 12),
            _statusCard(
              'Last Sync',
              _getLastSyncTime(),
              '',
              highlight: true,
              icon: Icons.refresh,
              onIconTap: _handleSync,
              iconAnimating: _syncing,
            ),
          ],
        ),
      ],
    );
  }

  int _calculateTotalUnsettled() {
    return _allUnsettledTransactions.fold<int>(0, (sum, txn) {
      final amount = txn['amount'] as int? ?? 0;
      return sum + amount.abs();
    });
  }

  String _getLastSyncTime() {
    if (_lastSyncTime == null) return 'Never';
    
    final now = DateTime.now();
    final diff = now.difference(_lastSyncTime!);
    
    if (diff.inSeconds < 5) return 'Just now';
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes == 1) return '1m ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours == 1) return '1h ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${diff.inDays ~/ 7}w ago';
    if (diff.inDays < 365) return '${diff.inDays ~/ 30}mo ago';
    return '${diff.inDays ~/ 365}y ago';
  }

  Widget _statusCard(
      String title,
      String value,
      String note, {
        bool highlight = false,
        IconData? icon,
        VoidCallback? onIconTap,
        bool iconAnimating = false,
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (icon != null)
                  GestureDetector(
                    onTap: onIconTap,
                    child: iconAnimating
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                highlight 
                                    ? const Color(0xFFE8FF3C) 
                                    : Colors.white54,
                              ),
                            ),
                          )
                        : Icon(
                            icon,
                            size: 20,
                            color: highlight 
                                ? const Color(0xFFE8FF3C) 
                                : Colors.white54,
                          ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (note.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(note, style: const TextStyle(color: Colors.white38)),
            ],
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
          child: _loadingTransactions
              ? const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFE8FF3C),
                      strokeWidth: 2,
                    ),
                  ),
                )
              : _recentTransactions.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          'No recent transactions',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        for (int i = 0; i < _recentTransactions.length; i++) ...[  if (i > 0)
                            Container(
                              height: 1,
                              color: const Color(0xFF2A2A2A),
                            ),
                          _buildTransactionItem(_recentTransactions[i]),
                        ],
                      ],
                    ),
        ),
      ],
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> txn) {
    final merchant = txn['merchant'] as String? ?? 'Unknown';
    final amount = txn['amount'] as int? ?? 0;
    final type = txn['type'] as String? ?? 'debit';
    final timestamp = txn['timestamp'] as String? ?? '';
    final isCredit = type == 'credit';
    final isUnsettled = txn['settledAt'] == null; // Check if transaction is unsettled
    
    // Format timestamp
    String timeStr = 'Just now';
    try {
      final dt = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) {
        timeStr = 'Just now';
      } else if (diff.inHours < 1) {
        timeStr = '${diff.inMinutes}m ago';
      } else if (diff.inDays < 1) {
        timeStr = '${diff.inHours}h ago';
      } else {
        timeStr = '${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      // Keep default
    }
    
    return _transactionItem(
      merchant,
      timeStr,
      '${isCredit ? '+' : '-'}$amount',
      negative: !isCredit,
      isUnsettled: isUnsettled,
    );
  }
  
  Widget _transactionItem(
      String name,
      String time,
      String amount, {
        bool negative = false,
        bool isUnsettled = false,
      }) {
    final initials = name.split(' ').take(2).map((e) => e.isNotEmpty ? e[0] : '?').join().toUpperCase();
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
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isUnsettled) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8FF3C).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: const Color(0xFFE8FF3C).withOpacity(0.4),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.schedule,
                          size: 12,
                          color: Color(0xFFE8FF3C),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: negative ? Colors.white : const Color(0xFF4ECDC4),
            ),
          ),
        ],
      ),
    );
  }
}
