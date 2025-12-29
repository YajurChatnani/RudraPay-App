import 'package:flutter/material.dart';
import '../services/wallet_service.dart';
import '../services/storage_service.dart';
import 'recharge_result_screen.dart';

class AddBalanceScreen extends StatefulWidget {
  const AddBalanceScreen({super.key});

  @override
  State<AddBalanceScreen> createState() => _AddBalanceScreenState();
}

class _AddBalanceScreenState extends State<AddBalanceScreen> {
  String? _selectedMethod;
  int _freeTokensLeft = 500;
  final TextEditingController _amountController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRemainingTokens();
  }

  Future<void> _loadRemainingTokens() async {
    final remaining = await StorageService.getRemainingFreeTokens();
    setState(() {
      _freeTokensLeft = remaining;
    });
  }

  // Payment methods configuration
  final List<PaymentMethod> _paymentMethods = [
    PaymentMethod(
      id: 'upi',
      title: 'UPI',
      description: 'Instant transfer via UPI',
      icon: Icons.phone_android,
      color: const Color(0xFF6C63FF),
      isDisabled: true,
    ),
    PaymentMethod(
      id: 'card',
      title: 'Debit/Credit Card',
      description: 'Add balance from your card',
      icon: Icons.credit_card,
      color: const Color(0xFF00D4FF),
      isDisabled: true,
    ),
    PaymentMethod(
      id: 'free_token',
      title: 'Free Token',
      description: 'Use your available free tokens',
      icon: Icons.card_giftcard,
      color: const Color(0xFF9C27B0),
      isFreeToken: true,
    ),
  ];

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: const Color(0xFF0B0B0B),
        child: Stack(
          children: [
            // 🌈 Ambient top-left glow
            Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.8, -0.9),
                  radius: 2.2,
                  colors: [
                    Color(0x2EE8FF3C),
                    Color(0x00000000),
                  ],
                  stops: [0.0, 1.0],
                ),
              ),
            ),

            // 🌑 Bottom vignette
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context),
                    const SizedBox(height: 32),
                    _buildAmountSection(),
                    const SizedBox(height: 32),
                    _buildPaymentMethodsSection(),
                    const SizedBox(height: 32),
                    if (_selectedMethod != null) _buildProceedButton(context),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Add Balance',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Choose a payment method',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white54,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAmountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ENTER AMOUNT',
          style: TextStyle(
            color: Colors.white38,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFFFFFFF).withValues(alpha: 0.15),
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              const Text(
                '₹',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w300,
                  color: Color(0xFFE8FF3C),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _amountController,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w300,
                  ),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: TextStyle(
                      fontSize: 28,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SELECT PAYMENT METHOD',
          style: TextStyle(
            color: Colors.white38,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _paymentMethods.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final method = _paymentMethods[index];
            final isSelected = _selectedMethod == method.id;

            return GestureDetector(
              onTap: method.isDisabled == true
                  ? null
                  : () {
                      setState(() {
                        _selectedMethod = method.id;
                      });
                    },
              child: Opacity(
                opacity: method.isDisabled == true ? 0.5 : 1.0,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? method.color.withValues(alpha: 0.15)
                        : const Color(0xFFFFFFFF).withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? method.color.withValues(alpha: 0.5)
                          : const Color(0xFFFFFFFF).withValues(alpha: 0.1),
                      width: isSelected ? 1.5 : 0.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: method.color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(
                              method.icon,
                              color: method.color,
                              size: 24,
                            ),
                            if (method.isDisabled == true)
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.black.withValues(alpha: 0.4),
                                ),
                                child: const Icon(
                                  Icons.lock,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      method.title,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (method.isDisabled == true)
                                      const SizedBox(height: 2),
                                    if (method.isDisabled == true)
                                      const Text(
                                        'Coming Soon',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.white38,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                  ],
                                ),
                                if (method.isFreeToken ?? false)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: method.color.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: method.color.withValues(alpha: 0.5),
                                        width: 0.5,
                                      ),
                                    ),
                                    child: Text(
                                      '$_freeTokensLeft left',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: method.color,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              method.description,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? method.color
                                : Colors.white.withValues(alpha: 0.3),
                            width: isSelected ? 6 : 1.5,
                          ),
                        ),
                        child: isSelected
                            ? Center(
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: method.color,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildProceedButton(BuildContext context) {
    final selectedMethod = _paymentMethods.firstWhere(
      (m) => m.id == _selectedMethod,
    );

    return Column(
      children: [
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  selectedMethod.color,
                  selectedMethod.color.withValues(alpha: 0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: selectedMethod.color.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isLoading ? null : () => _handleRecharge(context),
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_outline, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Proceed with ${selectedMethod.title}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleRecharge(BuildContext context) async {
    // Check if free tokens are exhausted
    final isExhausted = await StorageService.areFreeTokensExhausted();
    if (isExhausted) {
      _showErrorSnackbar(
        context,
        'Free tokens limit exhausted! You have used all 500 free tokens. No more tokens available.',
      );
      return;
    }

    // Validate amount input
    final amountStr = _amountController.text.trim();
    if (amountStr.isEmpty) {
      _showErrorSnackbar(context, 'Please enter an amount');
      return;
    }

    final amount = int.tryParse(amountStr);
    if (amount == null || amount <= 0) {
      _showErrorSnackbar(context, 'Please enter a valid amount');
      return;
    }

    if (amount > _freeTokensLeft) {
      _showErrorSnackbar(
        context,
        'Amount cannot exceed $_freeTokensLeft available tokens.\nYou have $_freeTokensLeft tokens remaining.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await WalletService.rechargeWallet(amount);

      if (response.success && mounted) {
        // Update used tokens counter
        final remaining = await StorageService.addUsedFreeTokens(amount);

        // Navigate to result screen
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 350),
            pageBuilder: (_, animation, __) => FadeTransition(
              opacity: animation,
              child: RechargeResultScreen(
                response: response,
                addedAmount: amount,
                remainingTokens: remaining,
              ),
            ),
          ),
        );
      } else if (mounted) {
        _showErrorSnackbar(context, response.message);
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = e.toString();
        if (errorMessage.startsWith('Exception: ')) {
          errorMessage = errorMessage.substring(11);
        }
        _showErrorSnackbar(context, errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        backgroundColor: Colors.red.withValues(alpha: 0.8),
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

// Payment Method Model
class PaymentMethod {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool? isFreeToken;
  final bool? isDisabled;

  PaymentMethod({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.isFreeToken = false,
    this.isDisabled = false,
  });
}
