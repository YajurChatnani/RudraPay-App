import 'package:flutter/material.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/services/auth_service.dart';

class OnboardingScreen extends StatefulWidget {
  final String? email;
  final String? password;

  const OnboardingScreen({super.key, this.email, this.password});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String _gender = 'male';
  int _step = 0;
  bool _loading = false;

  final Color _accent = const Color(0xFFE8FF3C);
  final Color _surface = const Color(0xFF111211);
  final Color _stroke = const Color(0xFF2B2C2B);

  @override
  void dispose() {
    _controller.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _next() {
    if (_step < 3) {
      _controller.nextPage(duration: const Duration(milliseconds: 240), curve: Curves.easeOut);
    } else {
      _register();
    }
  }

  Future<void> _register() async {
    final name = _nameController.text.trim();
    final age = int.tryParse(_ageController.text.trim());
    final phone = _phoneController.text.trim();
    final email = widget.email?.trim() ?? '';
    final password = widget.password ?? '';

    if (email.isEmpty || password.isEmpty) {
      _showSnack('Missing email or password from previous step');
      return;
    }
    if (name.isEmpty || age == null || phone.isEmpty) {
      _showSnack('Please complete all details');
      return;
    }

    setState(() => _loading = true);
    try {
      await AuthService.register(
        name: name,
        age: age,
        gender: _gender,
        phoneNumber: phone,
        email: email,
        password: password,
      );
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    } on AppException catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final steps = [
      _buildNameStep(),
      _buildAgeStep(),
      _buildGenderStep(),
      _buildPhoneStep(),
    ];

    final progress = (_step + 1) / steps.length;

    return Scaffold(
      body: Container(
        color: const Color(0xFF0B0B0B),
        child: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.8, -0.9),
                  radius: 2.2,
                  colors: [Color(0x2EE8FF3C), Color(0x00000000)],
                  stops: [0.0, 1.0],
                ),
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x000B0B0B), Color(0xFF0B0B0B)],
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: _step == 0
                                  ? () => Navigator.pushReplacementNamed(context, '/login')
                                  : () => _controller.previousPage(
                                        duration: const Duration(milliseconds: 200),
                                        curve: Curves.easeOut,
                                      ),
                              icon: const Icon(Icons.arrow_back, color: Colors.white),
                            ),
                            const Spacer(),
                            Text('Step ${_step + 1}/4', style: const TextStyle(color: Colors.white70, fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            return Stack(
                              children: [
                                Container(
                                  height: 6,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.white12,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  height: 6,
                                  width: constraints.maxWidth * progress,
                                  decoration: BoxDecoration(
                                    color: _accent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: PageView(
                      controller: _controller,
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (i) => setState(() => _step = i),
                      children: steps,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accent,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        onPressed: _loading ? null : _next,
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                              )
                            : Text(_step == steps.length - 1 ? 'Complete' : 'Continue'),
                      ),
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

  Widget _buildNameStep() {
    return _OnboardingStep(
      icon: Icons.person_outline,
      accent: _accent,
      title: "What's your name?",
      subtitle: "We'd like to know how to address you",
      child: _buildTextInput(
        label: 'Full Name',
        controller: _nameController,
        prefixIcon: Icons.badge_outlined,
        keyboardType: TextInputType.name,
      ),
    );
  }

  Widget _buildAgeStep() {
    return _OnboardingStep(
      icon: Icons.cake_outlined,
      accent: _accent,
      title: 'How old are you?',
      subtitle: 'We need this for verification purposes',
      child: _buildTextInput(
        label: 'Age',
        controller: _ageController,
        prefixIcon: Icons.event,
        keyboardType: TextInputType.number,
      ),
    );
  }

  Widget _buildGenderStep() {
    final options = [
      _GenderOption(label: 'Male', value: 'male', icon: Icons.male),
      _GenderOption(label: 'Female', value: 'female', icon: Icons.female),
      _GenderOption(label: 'Other', value: 'other', icon: Icons.transgender),
    ];

    return _OnboardingStep(
      icon: Icons.wc,
      accent: _accent,
      title: 'Select your gender',
      subtitle: 'This helps us personalize your experience',
      child: Column(
        children: options
            .map(
              (o) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _genderTile(option: o),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildPhoneStep() {
    return _OnboardingStep(
      icon: Icons.phone_in_talk_outlined,
      accent: _accent,
      title: 'Your phone number',
      subtitle: 'We\'ll use this to keep your account secure',
      child: _buildTextInput(
        label: 'Phone Number',
        controller: _phoneController,
        prefixIcon: Icons.phone_android,
        keyboardType: TextInputType.phone,
      ),
    );
  }

  Widget _buildTextInput({
    required String label,
    required TextEditingController controller,
    required IconData prefixIcon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        filled: true,
        fillColor: _surface,
        prefixIcon: Icon(prefixIcon, color: _accent),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: _stroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: _accent, width: 1.6),
        ),
      ),
    );
  }

  Widget _genderTile({required _GenderOption option}) {
    final selected = _gender == option.value;
    return GestureDetector(
      onTap: () => setState(() => _gender = option.value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? _accent : _stroke),
        ),
        child: Row(
          children: [
            Icon(option.icon, color: selected ? _accent : Colors.white60, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                option.label,
                style: TextStyle(
                  color: selected ? _accent : Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: selected ? _accent : Colors.white54,
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingStep extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final Widget child;

  const _OnboardingStep({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: accent.withOpacity(0.35),
                  blurRadius: 22,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(icon, size: 36, color: Colors.black),
          ),
          const SizedBox(height: 26),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.4),
          ),
          const SizedBox(height: 28),
          child,
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _GenderOption {
  final String label;
  final String value;
  final IconData icon;

  const _GenderOption({required this.label, required this.value, required this.icon});
}
