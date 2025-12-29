import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EnterAmountScreen extends StatefulWidget {
  const EnterAmountScreen({super.key});

  @override
  State<EnterAmountScreen> createState() => _EnterAmountScreenState();
}

class _EnterAmountScreenState extends State<EnterAmountScreen> {
  final TextEditingController _controller = TextEditingController(text: '0');

  int get amount => int.tryParse(_controller.text.replaceAll(RegExp(r'\D'), '')) ?? 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            // ===== SCROLLABLE TOP SECTION =====
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Text(
                          '← Back',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),

                    const Divider(color: Colors.white12),

                    // Paying to
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'PAYING TO',
                            style: TextStyle(
                              fontSize: 12,
                              letterSpacing: 1.2,
                              color: Colors.white38,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'CafeX Store',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Via Bluetooth',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Divider(color: Colors.white12),

                    // Amount
                    const SizedBox(height: 96),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: _controller,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 64,
                            fontWeight: FontWeight.w300,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(border: InputBorder.none),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Indian Rupees (₹)',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 96),
                  ],
                ),
              ),
            ),

            // ===== FIXED BOTTOM SECTION =====
            Container(
              color: const Color(0xFF0B0B0B),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(color: Colors.white12),

                  // Paying from
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Column(
                      children: const [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Paying from', style: TextStyle(color: Colors.white54)),
                            Text('Wallet balance', style: TextStyle(fontWeight: FontWeight.w500)),
                          ],
                        ),
                        SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Available', style: TextStyle(color: Colors.white54)),
                            Text('₹2,450', style: TextStyle(fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),
                  const Center(
                    child: Text(
                      'Payment will be settled later',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white38,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Slide to pay
                  Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset + 16),
                    child: _SlideToPay(
                      enabled: amount > 0,
                      label: amount > 0 ? 'Slide to pay ₹$amount' : 'Enter amount to pay',
                      onConfirmed: amount > 0
                          ? () {
                        Navigator.pushNamed(context, '/pay/pending');
                            }
                          : null,
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

// ================= SLIDE TO PAY =================

class _SlideToPay extends StatefulWidget {
  final bool enabled;
  final String label;
  final VoidCallback? onConfirmed;

  const _SlideToPay({
    required this.enabled,
    required this.label,
    required this.onConfirmed,
  });

  @override
  State<_SlideToPay> createState() => _SlideToPayState();
}

class _SlideToPayState extends State<_SlideToPay>
    with SingleTickerProviderStateMixin {
  late AnimationController _resetController;
  late Animation<double> _resetAnim;
  double _thumbX = 0.0; // 0..1
  bool _confirmed = false;

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _resetAnim = CurvedAnimation(
      parent: _resetController,
      curve: Curves.easeOut,
    )..addListener(() {
        setState(() {
          _thumbX = _thumbX * (1.0 - _resetAnim.value);
        });
      });
  }

  @override
  void dispose() {
    _resetController.dispose();
    super.dispose();
  }

  void _onPanUpdate(double dx, double max) {
    if (!widget.enabled || _confirmed) return;
    final next = ((_thumbX * max) + dx).clamp(0.0, max) / max;
    setState(() => _thumbX = next);
  }

  void _onPanEnd() {
    if (!widget.enabled || _confirmed) return;
    if (_thumbX > 0.88) {
      setState(() => _confirmed = true);
      widget.onConfirmed?.call();
      // Keep thumb at end visually; no reset here.
    } else {
      _resetController.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF18A561);
    final bgColor = widget.enabled ? accent : accent.withValues(alpha: 0.35);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = 56.0;
        final padding = 2.0; // keep low to fit larger arrows
        final trackRadius = height / 2;
        final thumbSize = height - padding * 2;
        final maxTravel = width - padding * 2 - thumbSize;
        final thumbLeft = padding + maxTravel * _thumbX;
        final fillWidth = thumbLeft + thumbSize * 0.6;
        const Color thumbColor = Colors.white;

        final leftArrowColor = accent.withValues(alpha: 0.65);
        final rightArrowColor = accent;

        return Container(
          height: height,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(trackRadius),
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                width: fillWidth.clamp(thumbSize, width),
                height: height,
                decoration: BoxDecoration(
                  color: widget.enabled
                      ? accent
                      : accent.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(trackRadius),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: widget.enabled ? Colors.white : Colors.white54,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: thumbLeft,
                top: padding,
                child: GestureDetector(
                  onPanUpdate: (details) => _onPanUpdate(details.delta.dx, maxTravel),
                  onPanEnd: (_) => _onPanEnd(),
                  child: Container(
                    height: thumbSize,
                    width: thumbSize,
                    decoration: BoxDecoration(
                      color: thumbColor,
                      shape: BoxShape.circle,
                      boxShadow: widget.enabled
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Transform.translate(
                            offset: const Offset(10, 0),
                            child: Icon(
                              Icons.chevron_right,
                              size: 64,
                              color: leftArrowColor,
                            ),
                          ),
                          Transform.translate(
                            offset: const Offset(-18, 0),
                            child: Icon(
                              Icons.chevron_right,
                              size: 64,
                              color: rightArrowColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
