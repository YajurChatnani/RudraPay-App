import 'package:flutter/material.dart';
import '../../../core/services/classic_bluetooth_service.dart';
import '../../../core/services/token_service.dart';

class ReceiveBluetoothConnectingScreen extends StatefulWidget {
  const ReceiveBluetoothConnectingScreen({super.key});

  @override
  State<ReceiveBluetoothConnectingScreen> createState() =>
      _ReceiveBluetoothConnectingScreenState();
}

class _ReceiveBluetoothConnectingScreenState
    extends State<ReceiveBluetoothConnectingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final ClassicBluetoothService _bluetoothService = ClassicBluetoothService();
  
  String _statusMessage = 'Initializing Bluetooth...';
  String? _userName;
  String? _deviceName;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    
    _initialize();
  }

  Future<void> _initialize() async {
    print('[RECEIVE-CONNECT] Initializing...');
    
    // Load user info
    final user = await TokenService.getUser();
    
    // Get device name
    final deviceName = await ClassicBluetoothService.getDeviceName();
    
    setState(() {
      _userName = user?.name ?? 'User';
      _deviceName = deviceName;
    });

    // Initialize Bluetooth
    final initialized = await _bluetoothService.initialize('receive');
    
    if (!initialized) {
      setState(() {
        _statusMessage = 'Bluetooth not available';
      });
      _showError('Bluetooth is not available on this device');
      return;
    }

    print('[RECEIVE-CONNECT] Bluetooth initialized, starting server...');
    setState(() {
      _statusMessage = 'Starting payment receiver...';
    });

    // Start listening for connections
    await _startListening();
  }

  Future<void> _startListening() async {
    try {
      print('[RECEIVE-CONNECT] Starting to listen for sender connections...');
      
      setState(() {
        _isListening = true;
        _statusMessage = 'Listening for sender...';
      });
      
      await _bluetoothService.startListening(
        _deviceName ?? 'RudraPay Device',
        (connectionInfo) {
          print('[RECEIVE-CONNECT] Sender connected! info=$connectionInfo');
          
          if (mounted) {
            // Navigate to payment screen with connection handle
            Navigator.pushReplacementNamed(
              context,
              '/receive/connected',
              arguments: {
                'deviceName': connectionInfo['name'] ?? 'Sender Device',
                'userName': _userName,
                'connectionHandle': connectionInfo['handle'],
                'connectionAddress': connectionInfo['address'],
              },
            );
          }
        },
      );
      
    } catch (e) {
      print('[RECEIVE-CONNECT ERROR] Listening failed: $e');
      if (mounted) {
        setState(() {
          _statusMessage = 'Failed to listen for connections';
          _isListening = false;
        });
      }
      _showError('Failed to start listening: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                ),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.arrow_back_ios_new, size: 24, color: Colors.white),
                              SizedBox(width: 6),
                              Text('Back', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white70)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                height: 200,
                                width: 200,
                                child: AnimatedBuilder(
                                  animation: _controller,
                                  builder: (_, __) => CustomPaint(
                                    painter: _PulsePainter(_controller.value),
                                  ),
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    height: 80,
                                    width: 80,
                                    decoration: BoxDecoration(
                                      color: _isListening 
                                        ? const Color(0xFFE8FF3C).withValues(alpha: 0.3)
                                        : const Color(0xFFFFFFFF).withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _isListening 
                                        ? Icons.bluetooth_audio
                                        : Icons.bluetooth_searching,
                                      size: 40,
                                      color: _isListening
                                        ? const Color(0xFFE8FF3C)
                                        : Colors.white54,
                                    ),
                                  ),
                                  if (_isListening) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE8FF3C).withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: const Color(0xFFE8FF3C).withValues(alpha: 0.5),
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            _deviceName ?? 'Loading...',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFFE8FF3C),
                                            ),
                                          ),
                                          if (_userName != null) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              _userName!,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFFE8FF3C),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          Text(
                            _isListening ? 'Ready to Receive' : 'Starting up...',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: Text(
                              _statusMessage,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white54,
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFFFF).withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFFFFFFF).withValues(alpha: 0.1),
                              ),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.info_outline, size: 20, color: Colors.white38),
                                const SizedBox(height: 8),
                                Text(
                                  _isListening
                                    ? 'Your device is visible as "$_deviceName"\nWaiting for sender to connect...'
                                    : 'Starting Bluetooth server...',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.white38,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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
}

class _PulsePainter extends CustomPainter {
  final double progress;
  _PulsePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    for (int i = 0; i < 3; i++) {
      final ringProgress = (progress + i * 0.33) % 1.0;
      final radius = _lerp(20, maxRadius, ringProgress);
      final opacity = (1 - ringProgress).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = Colors.white.withValues(alpha: opacity * 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawCircle(center, radius, paint);
    }
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  bool shouldRepaint(_) => true;
}
