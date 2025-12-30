import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import '../../../core/services/classic_bluetooth_service.dart';
import '../../../core/services/token_service.dart';

class PayBluetoothConnectingScreen extends StatefulWidget {
  const PayBluetoothConnectingScreen({super.key});

  @override
  State<PayBluetoothConnectingScreen> createState() =>
      _PayBluetoothConnectingScreenState();
}

class _PayBluetoothConnectingScreenState
    extends State<PayBluetoothConnectingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final ClassicBluetoothService _bluetoothService = ClassicBluetoothService();
  
  List<BluetoothDevice> _foundDevices = [];
  bool _isScanning = true;
  bool _isConnecting = false;
  String _statusMessage = 'Initializing Bluetooth...';
  String? _userName;

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
    print('[PAY-CONNECT] Initializing...');
    
    // Load user info
    final user = await TokenService.getUser();
    setState(() {
      _userName = user?.name ?? 'User';
    });

    // Initialize Bluetooth
    final initialized = await _bluetoothService.initialize('sender');
    
    if (!initialized) {
      setState(() {
        _statusMessage = 'Bluetooth not available';
        _isScanning = false;
      });
      _showError('Bluetooth is not available on this device');
      return;
    }

    print('[PAY-CONNECT] Bluetooth initialized, starting scan...');
    setState(() {
      _statusMessage = 'Searching for nearby devices...';
    });

    // Start scanning
    await _startScanning();
  }

  Future<void> _startScanning() async {
    try {
      print('[PAY-CONNECT] Starting device scan...');
      
      final devices = await _bluetoothService.scanForDevices();
      
      print('[PAY-CONNECT] Scan completed, found ${devices.length} device(s)');
      
      if (mounted) {
        setState(() {
          _foundDevices = devices;
          _isScanning = false;
          _statusMessage = devices.isEmpty 
              ? 'No devices found nearby' 
              : 'Found ${devices.length} device(s)';
        });
      }

      if (devices.isEmpty) {
        _showInfo('No devices found. Make sure receiver has Bluetooth ON and is in "Receive" mode.');
      }
    } catch (e) {
      print('[PAY-CONNECT ERROR] Scan failed: $e');
      if (mounted) {
        setState(() {
          _isScanning = false;
          _statusMessage = 'Scan failed';
        });
      }
      _showError('Failed to scan for devices: $e');
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      print('[PAY-CONNECT] Connecting to ${device.name ?? 'Unknown'}...');
      
      setState(() {
        _isConnecting = true;
        _statusMessage = 'Connecting to ${device.name ?? 'Unknown'}...';
      });

      await _bluetoothService.connectToDevice(device, (connectionInfo) {
        if (mounted) {
          print('[PAY-CONNECT] Connected successfully: $connectionInfo');
          
          // Navigate directly to amount screen with connection details
          final remoteName = connectionInfo['name']
              ?? device.name
              ?? connectionInfo['address']
              ?? 'Unknown Device';

          Navigator.pushReplacementNamed(
            context,
            '/pay/amount',
            arguments: {
              'deviceName': remoteName,
              'userName': _userName,
              'connectionHandle': connectionInfo['handle'],
              'connectionAddress': connectionInfo['address'],
            },
          );
        }
      });

    } catch (e) {
      print('[PAY-CONNECT ERROR] Connection failed: $e');
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _statusMessage = 'Connection failed';
        });
      }
      
      String errorMessage = 'Failed to connect: $e';
      if (e.toString().contains('timeout')) {
        errorMessage = 'Connection timeout - Make sure receiver device is ready and waiting in Receive mode';
      }
      
      _showError(errorMessage);
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

  void _showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.blue.withValues(alpha: 0.9),
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

                  if (_isScanning) ...[
                    const SizedBox(height: 80),
                    SizedBox(
                      height: 160,
                      width: 160,
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (_, __) => CustomPaint(painter: _PulsePainter(_controller.value)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text('Scanning...', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(_statusMessage, style: const TextStyle(fontSize: 14, color: Colors.white54)),
                  ] else if (_isConnecting) ...[
                    const SizedBox(height: 80),
                    const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE8FF3C))),
                    const SizedBox(height: 24),
                    const Text('Connecting...', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(_statusMessage, style: const TextStyle(fontSize: 14, color: Colors.white54)),
                  ] else ...[
                    Expanded(
                      child: _foundDevices.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.bluetooth_searching, size: 64, color: Colors.white24),
                                  const SizedBox(height: 16),
                                  const Text('No devices found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 8),
                                  const Text('Make sure receiver is nearby', style: TextStyle(fontSize: 14, color: Colors.white54)),
                                  const SizedBox(height: 32),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _isScanning = true;
                                        _statusMessage = 'Searching...';
                                      });
                                      _startScanning();
                                    },
                                    icon: const Icon(Icons.refresh, color: Colors.black),
                                    label: const Text('Scan Again'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFE8FF3C),
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _foundDevices.length,
                              itemBuilder: (context, index) => _buildDeviceCard(_foundDevices[index]),
                            ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceCard(BluetoothDevice device) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFFFFF).withValues(alpha: 0.15)),
      ),
      child: ListTile(
        leading: Container(
          height: 48,
          width: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFE8FF3C).withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.bluetooth, color: Color(0xFFE8FF3C)),
        ),
        title: Text(
          device.name?.isNotEmpty ?? false ? device.name! : 'Unknown Device',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          device.address,
          style: const TextStyle(fontSize: 12, color: Colors.white54),
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white.withValues(alpha: 0.5)),
        onTap: () => _connectToDevice(device),
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
