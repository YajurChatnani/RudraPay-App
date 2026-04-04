import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/utils/async_timing.dart';
import '../../balance/models/recharge_response.dart' show Token;
import '../../balance/services/wallet_keypair_service.dart';
import '../services/qr_unlock_flow_service.dart';
import '../../balance/services/token_lock_service.dart';
import '../../bluetooth/services/classic_bluetooth_service.dart';

class AcceptPaymentQrScreen extends StatefulWidget {
  const AcceptPaymentQrScreen({super.key});

  @override
  State<AcceptPaymentQrScreen> createState() => _AcceptPaymentQrScreenState();
}

class _AcceptPaymentQrScreenState extends State<AcceptPaymentQrScreen> {
  bool _isBusy = false;
  UnlockPreview? _preview;
  String? _qrPayload;
  String? _error;
  bool _didLoadArgs = false;
  bool _didAutoOpenScanner = false;
  String? _expectedTxnId;
  String? _senderName;
  List<Token>? _preloadedLockedTokens;
  int? _connectionHandle;
  final ClassicBluetoothService _classicService = ClassicBluetoothService();

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[ACCEPT-QR] $message');
    }
  }

  Future<String> _loadMyPublicKey() async {
    final keyPair = await traceAwait('[ACCEPT-QR] WalletKeyPairService.getOrCreateKeyPair', WalletKeyPairService.getOrCreateKeyPair());
    return keyPair.publicKeyPem;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoadArgs) return;
    _didLoadArgs = true;

    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _expectedTxnId = args?['expectedTxnId'] as String?;
    _senderName = args?['senderName'] as String?;
    _connectionHandle = args?['connectionHandle'] as int?;
    final tokensArg = args?['lockedTokens'];
    if (tokensArg is List<Token>) {
      _preloadedLockedTokens = tokensArg;
    } else if (tokensArg is List) {
      _preloadedLockedTokens = tokensArg
          .whereType<Map<String, dynamic>>()
          .map(Token.fromJson)
          .toList(growable: false);
    }
    _log('Screen initialized expectedTxnId=${_expectedTxnId ?? '-'}');

    if (!_didAutoOpenScanner) {
      _didAutoOpenScanner = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _openQrScanner();
      });
    }
  }

  Future<void> _notifySenderTokenUnlocked(UnlockResult result) async {
    final handle = _connectionHandle;
    if (handle == null) {
      _log('No connection handle available, skipping token_unlocked ack');
      return;
    }

    final confirmation = {
      'type': 'token_unlocked',
      'txnId': result.txnId,
      'status': 'success',
      'message': 'Receiver scanned QR and unlocked tokens',
      'tokenCount': result.tokenCount,
      'amount': result.totalValue,
      'timestamp': DateTime.now().toIso8601String(),
    };

    await traceAwait(
      '[ACCEPT-QR] ClassicBluetoothService.sendBytes token_unlocked',
      _classicService.sendBytes(
        handle,
        Uint8List.fromList(utf8.encode(jsonEncode(confirmation))),
      ),
    );
    _log('token_unlocked ack sent to sender');
  }

  Future<void> onQrScanned(String qrPayload) async {
    _log('QR scanned payloadLength=${qrPayload.length}');
    setState(() {
      _isBusy = true;
      _error = null;
      _preview = null;
      _qrPayload = qrPayload;
    });

    try {
      // Auto-unlock immediately after scan to remove extra confirmation step.
      final myPubKey = await traceAwait('[ACCEPT-QR] _loadMyPublicKey unlock', _loadMyPublicKey());
      final result = await traceAwait(
        '[ACCEPT-QR] QrUnlockFlowService.confirmAndUnlock',
        QrUnlockFlowService.confirmAndUnlock(
          qrPayload: qrPayload,
          myPubKey: myPubKey,
          preloadedLockedTokens: _preloadedLockedTokens,
        ),
      );

      if (_expectedTxnId != null &&
          _expectedTxnId!.isNotEmpty &&
          _expectedTxnId != result.txnId) {
        _log('Partial mismatch expectedTxnId=$_expectedTxnId unlockedTxnId=${result.txnId}');
        throw const TokenLockException('Partial mismatch: QR txn_id does not match locked transfer');
      }

      await _notifySenderTokenUnlocked(result);

      if (!mounted) return;
      _log('Auto-unlock complete, ack sent, navigating to /transaction/result');
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/transaction/result',
        (route) => false,
        arguments: {
          'amount': result.totalValue,
          'otherPartyName': _senderName ?? 'Sender',
          'txnId': result.txnId,
          'method': 'QR Unlock',
          'message': 'Payment received successfully',
          'isReceiver': true,
        },
      );
    } on FormatException {
      _log('Invalid QR format');
      if (!mounted) return;
      setState(() {
        _error = 'Invalid QR';
      });
    } on TokenLockException catch (e) {
      _log('QR validation failed: ${e.message}');
      if (!mounted) return;
      setState(() {
        _error = e.message;
      });
    } catch (_) {
      _log('Unknown QR parsing failure');
      if (!mounted) return;
      setState(() {
        _error = 'Invalid QR';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _openQrScanner() async {
    final hasPermission = await traceAwait('[ACCEPT-QR] _ensureCameraPermission', _ensureCameraPermission());
    if (!hasPermission) {
      return;
    }

    _log('Opening camera scanner dialog');
    final controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      returnImage: false,
    );

    var didScan = false;

    try {
      final scannedPayload = await traceAwait(
        '[ACCEPT-QR] showDialog scanner',
        showDialog<String>(
          context: context,
          barrierDismissible: true,
          builder: (dialogContext) {
            return Dialog(
              backgroundColor: const Color(0xFF111111),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Scan Unlock QR',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: 280,
                      height: 280,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: MobileScanner(
                          controller: controller,
                          onDetect: (capture) {
                            if (didScan) return;

                            final barcodes = capture.barcodes;
                            if (barcodes.isEmpty) return;

                            final rawValue = barcodes.first.rawValue;
                            if (rawValue == null || rawValue.isEmpty) return;

                            didScan = true;
                            _log('Camera detected QR code, closing scanner dialog');
                            Navigator.of(dialogContext).pop(rawValue);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );

      if (!mounted || scannedPayload == null || scannedPayload.isEmpty) {
        _log('Scanner closed without payload');
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/home',
          (route) => false,
        );
        return;
      }

      await traceAwait('[ACCEPT-QR] onQrScanned', onQrScanned(scannedPayload));
    } finally {
      _log('Disposing scanner controller');
      await traceAwait('[ACCEPT-QR] MobileScannerController.dispose', controller.dispose());
    }
  }

  Future<bool> _ensureCameraPermission() async {
    var status = await traceAwait('[ACCEPT-QR] Permission.camera.status', Permission.camera.status);

    if (status.isGranted) {
      _log('Camera permission already granted');
      return true;
    }

    _log('Requesting camera permission');
    status = await traceAwait('[ACCEPT-QR] Permission.camera.request', Permission.camera.request());

    if (status.isGranted) {
      _log('Camera permission granted after request');
      return true;
    }

    if (status.isPermanentlyDenied) {
      _log('Camera permission permanently denied');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Camera permission is blocked. Open app settings to allow scanning.'),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: openAppSettings,
            ),
          ),
        );
      }
      return false;
    }

    _log('Camera permission denied');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera permission is required to scan QR code.')),
      );
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B0B),
        title: const Text('Accept Payment'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            const Text(
              'Opening scanner...',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            if (_isBusy) ...[
              const SizedBox(height: 16),
              const Text(
                'Processing unlock...',
                textAlign: TextAlign.center,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
