import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---------------- BACK ----------------
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
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

              const SizedBox(height: 24),

              // =========================
              // 1. USER IDENTITY
              // =========================
              Center(
                child: Column(
                  children: const [
                    Text(
                      'Yajur Chatnani',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Wallet owner',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white54,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      '+91 •••• 7974',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
              const Divider(color: Colors.white12),

              // =========================
              // 2. PERSONAL DETAILS
              // =========================
              const SizedBox(height: 24),
              const _SectionTitle('Personal details'),

              const SizedBox(height: 16),

              _PersonalDetailRow(
                label: 'Name',
                value: 'Yajur Chatnani',
              ),

              _PersonalDetailRow(
                label: 'Phone',
                value: '9109447974',
              ),

              _PersonalDetailRow(
                label: 'Unique App ID',
                value: _generateUniqueAppId(),
                isCopyable: true,
              ),

              const SizedBox(height: 24),
              const Divider(color: Colors.white12),

              // =========================
              // 3. PAYMENT DETAILS
              // =========================
              const SizedBox(height: 24),
              const _SectionTitle('Payment details'),

              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'WLT-8F3A-92KD',
                    style: TextStyle(
                      fontSize: 15,
                      fontFamily: 'monospace',
                    ),
                  ),
                  _OutlineButton(
                    label: 'Copy',
                    onTap: () {
                      Clipboard.setData(
                        const ClipboardData(text: 'WLT-8F3A-92KD'),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Wallet ID copied'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 24),
              const Divider(color: Colors.white12),

              // =========================
              // 4. SECURITY STATUS
              // =========================
              const SizedBox(height: 24),
              const _SectionTitle('Security status'),

              const SizedBox(height: 16),

              _SecurityRow(
                label: 'Device security',
                status: 'Secure',
              ),

              _SecurityRow(
                label: 'App integrity',
                status: 'Verified',
              ),

              _SecurityRow(
                label: 'Connection',
                status: 'No active',
              ),

              const SizedBox(height: 40),
              const Divider(color: Colors.white12),

              // =========================
              // FOOTER
              // =========================
              const SizedBox(height: 16),
              Center(
                child: Column(
                  children: const [
                    Text(
                      'App version 1.0.0',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white38,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Development Environment',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white24,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  /// Generates a cryptographically unique app ID
  static String _generateUniqueAppId() {
    // Use device ID or user-specific seed for production
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final seed = 'RUDRAPAY-$timestamp-Yajur';
    final bytes = utf8.encode(seed);
    final hash = sha256.convert(bytes);
    return hash.toString().substring(0, 32).toUpperCase();
  }
}

// =======================================================
// SECTION TITLE
// =======================================================

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        letterSpacing: 1,
        color: Colors.white54,
      ),
    );
  }
}

// =======================================================
// SECURITY ROW
// =======================================================

class _SecurityRow extends StatelessWidget {
  final String label;
  final String status;

  const _SecurityRow({
    required this.label,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
              ),
            ),
          ),

          // Status
          Row(
            children: [
              Container(
                height: 8,
                width: 8,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                status,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white54,
                ),
              ),
            ],
          ),

          const SizedBox(width: 16),

          _OutlineButton(
            label: 'Refresh',
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

// =======================================================
// PERSONAL DETAIL ROW
// =======================================================

class _PersonalDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isCopyable;

  const _PersonalDetailRow({
    required this.label,
    required this.value,
    this.isCopyable = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white54,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontFamily: 'monospace',
              ),
            ),
          ),
          if (isCopyable) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Copied to clipboard'),
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              child: const Icon(
                Icons.copy,
                size: 16,
                color: Colors.white38,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// =======================================================
// OUTLINE BUTTON
// =======================================================

class _OutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _OutlineButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white24),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.white70,
          ),
        ),
      ),
    );
  }
}
