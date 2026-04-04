import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/utils/async_timing.dart';
import '../../balance/models/recharge_response.dart' show Token;
import '../../balance/services/wallet_keypair_service.dart';
import '../services/qr_unlock_flow_service.dart';
import '../../balance/services/token_lock_service.dart';

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
  String? _expectedTxnId;
  List<Token>? _preloadedLockedTokens;

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
      final myPubKey = await traceAwait('[ACCEPT-QR] _loadMyPublicKey preview', _loadMyPublicKey());
      final preview = await traceAwait(
        '[ACCEPT-QR] QrUnlockFlowService.buildPreview',
        QrUnlockFlowService.buildPreview(
          qrPayload: qrPayload,
          myPubKey: myPubKey,
          preloadedLockedTokens: _preloadedLockedTokens,
        ),
      );
      _log('Preview ready txnId=${preview.txnId}, tokens=${preview.tokenCount}, total=${preview.totalValue}');

      if (_expectedTxnId != null && _expectedTxnId!.isNotEmpty && _expectedTxnId != preview.txnId) {
        _log('Partial mismatch expectedTxnId=$_expectedTxnId scannedTxnId=${preview.txnId}');
        throw const TokenLockException('Partial mismatch: QR txn_id does not match locked transfer');
      }

      if (!mounted) return;
      setState(() {
        _preview = preview;
      });
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

  Future<void> onConfirmUnlock() async {
    if (_qrPayload == null) return;
    _log('Confirm unlock tapped');

    setState(() {
      _isBusy = true;
      _error = null;
    });

    try {
      final myPubKey = await traceAwait('[ACCEPT-QR] _loadMyPublicKey unlock', _loadMyPublicKey());
      final result = await traceAwait(
        '[ACCEPT-QR] QrUnlockFlowService.confirmAndUnlock',
        QrUnlockFlowService.confirmAndUnlock(
          qrPayload: _qrPayload!,
          myPubKey: myPubKey,
          preloadedLockedTokens: _preloadedLockedTokens,
        ),
      );
      _log('Unlock success txnId=${result.txnId}, tokens=${result.tokenCount}, total=${result.totalValue}');
      for (final token in result.unlockedTokens) {
        _log('Unlocked token tokenId=${token.tokenId}, value=${token.value}');
      }

      if (!mounted) return;
      _log('Navigating to confirmation screen /transaction/result');
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/transaction/result',
        (route) => false,
        arguments: {
          'amount': result.totalValue,
          'otherPartyName': 'Sender',
          'txnId': result.txnId,
          'method': 'QR Unlock',
          'message': 'Batch unlock successful (${result.tokenCount} tokens)',
          'isReceiver': true,
        },
      );
    } on TokenLockException catch (e) {
      _log('Unlock failed: ${e.message}');
      if (!mounted) return;
      setState(() {
        _error = e.message;
      });
    } catch (_) {
      _log('Unlock failed: unknown error');
      if (!mounted) return;
      setState(() {
        _error = 'Unable to unlock tokens';
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
            ElevatedButton(
              onPressed: _isBusy
                  ? null
                  : _openQrScanner,
              child: const Text('Scan QR'),
            ),
            if (_preview != null) ...[
              const SizedBox(height: 16),
              Text('Tokens: ${_preview!.tokenCount}'),
              Text('Total value: ${_preview!.totalValue}'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _isBusy ? null : onConfirmUnlock,
                child: const Text('Confirm & Unlock'),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
