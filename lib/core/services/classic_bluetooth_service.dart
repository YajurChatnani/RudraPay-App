import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart' as fbs;
import 'package:permission_handler/permission_handler.dart';

/// Real Bluetooth service using flutter_bluetooth_serial
class ClassicBluetoothService {
  static const platform = MethodChannel('com.rudrapay.app/classic_bt');
  static const _eventChannel = EventChannel('com.rudrapay.app/classic_bt_stream');

  final fbs.FlutterBluetoothSerial _bluetooth = fbs.FlutterBluetoothSerial.instance;
  fbs.BluetoothConnection? _connection;
  fbs.BluetoothConnection? _serverConnection;
  StreamSubscription<Uint8List>? _dataSubscription;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _nativeEventSub;
  final Map<int, StreamController<Uint8List>> _streamControllers = {};
  
  // UUID for SPP (Serial Port Profile)
  static const String _sppUuid = '00001101-0000-1000-8000-00805F9B34FB';
  static const String _serviceName = 'RudraPay';

  void _ensureNativeEventListener() {
    if (_nativeEventSub != null) return;

    _nativeEventSub = _eventChannel.receiveBroadcastStream().listen(
      (event) {
        try {
          final map = Map<String, dynamic>.from(event as Map);
          final handle = map['handle'];
          final data = map['data'];

          if (handle is int) {
            if (data is Uint8List) {
              _streamControllers[handle]?.add(data);
            } else if (data is List) {
              _streamControllers[handle]?.add(Uint8List.fromList(data.cast<int>()));
            }
          }
        } catch (e) {
          print('Native event parse error: $e');
        }
      },
      onError: (e) {
        print('Native event error: $e');
      },
    );
  }

  Stream<Uint8List> _getStreamForHandle(int handle) {
    _streamControllers.putIfAbsent(handle, () => StreamController<Uint8List>.broadcast());
    _ensureNativeEventListener();
    return _streamControllers[handle]!.stream;
  }
  
  bool get isAvailable => true;

  Future<bool> initialize(String mode) async {
    try {
      print('Initializing Bluetooth...');
      
      // Check if Bluetooth is available on the device
      bool? isAvailableOnDevice = await _bluetooth.isAvailable;
      if (isAvailableOnDevice != true) {
        print('Bluetooth is not available on this device');
        return false;
      }
      
      // Request Bluetooth permissions (for Android 12+)
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();
      
      print('Permission statuses: $statuses');
      
      // Check if essential permissions are granted
      bool scanGranted = statuses[Permission.bluetoothScan]?.isGranted ?? false;
      bool connectGranted = statuses[Permission.bluetoothConnect]?.isGranted ?? false;
      bool locationGranted = statuses[Permission.location]?.isGranted ?? false;
      
      if (!scanGranted || !connectGranted || !locationGranted) {
        print('Required permissions not granted');
        print('Scan: $scanGranted, Connect: $connectGranted, Location: $locationGranted');
        return false;
      }
      
      // Check if Bluetooth is enabled
      bool? isEnabled = await _bluetooth.isEnabled;
      print('Bluetooth enabled: $isEnabled');
      
      if (isEnabled != true) {
        // Request to enable Bluetooth
        print('Requesting to enable Bluetooth...');
        bool? enabled = await _bluetooth.requestEnable();
        if (enabled != true) {
          print('User declined to enable Bluetooth');
          return false;
        }
      }
      
      print('Bluetooth initialized successfully');
      return true;
    } catch (e) {
      print('Bluetooth initialization error: $e');
      return false;
    }
  }

  Future<List<BluetoothDevice>> scanForDevices() async {
    try {
      // Get both bonded devices and discover new ones
      List<fbs.BluetoothDevice> devices = [];
      
      // First get bonded devices
      try {
        final bondedDevices = await _bluetooth.getBondedDevices();
        devices.addAll(bondedDevices);
        print('Found ${bondedDevices.length} bonded device(s)');
      } catch (e) {
        print('Error getting bonded devices: $e');
      }
      
      // Then start discovery for new devices (timeout after 12 seconds)
      try {
        print('Starting device discovery...');
        final discoveryStream = _bluetooth.startDiscovery();
        
        // Listen to discovery stream for 12 seconds
        await discoveryStream.timeout(
          const Duration(seconds: 12),
          onTimeout: (sink) {
            print('Discovery timeout');
            sink.close();
          },
        ).listen((result) {
          // Results come through the stream
        }).asFuture();
      } catch (e) {
        // Timeout is expected, so we ignore it
        print('Discovery completed or timed out');
      }
      
      // Get bonded devices again to see if any new ones were added
      try {
        final bondedDevices = await _bluetooth.getBondedDevices();
        devices = bondedDevices;
        print('Found ${devices.length} total device(s) after discovery');
      } catch (e) {
        print('Error getting devices after discovery: $e');
      }
      
      return devices.map((d) => BluetoothDevice(
        address: d.address,
        name: d.name ?? 'Unknown Device',
      )).toList();
    } catch (e) {
      print('Scan error: $e');
      return [];
    }
  }

  Future<void> connectToDevice(
    BluetoothDevice device,
    void Function(Map<String, dynamic>) onConnected,
  ) async {
    try {
      print('Attempting to connect (native) to ${device.address}...');

      // Ensure paired
      try {
        print('Ensuring device is paired...');
        bool? bonded = await _bluetooth.bondDeviceAtAddress(device.address);
        print('Pairing status: $bonded');
      } catch (e) {
        print('Pairing attempt: $e');
      }

      await Future.delayed(const Duration(milliseconds: 300));

      // Native connect via method channel (registers socket handle for sendBytes)
      final result = await platform.invokeMethod<Map>('connect', {
        'uuid': _sppUuid,
        'address': device.address,
        'timeoutSec': 30,
      });

      final handle = result?['handle'] as int?;
      final name = result?['name'] as String? ?? device.name;
      final address = result?['address'] as String? ?? device.address;

      print('Connection established to $name');

      // Notify immediately that connection is successful
      onConnected({
        'handle': handle ?? address.hashCode,
        'address': address,
        'name': name,
        'status': 'connected',
      });

    } catch (e) {
      print('Connection failed: $e');
      throw Exception('Failed to connect: $e');
    }
  }

  Future<void> startListening(
    String deviceName,
    void Function(Map<String, dynamic>) onConnection,
  ) async {
    try {
      print('Starting listening mode for device: $deviceName');
      
      // Call native Android code to start Bluetooth server socket
      try {
        final result = await platform.invokeMethod<Map>('startServer', {
          'uuid': _sppUuid,
          'serviceName': _serviceName,
          'timeoutSec': 300,
        });
        
        if (result != null) {
          print('Receiver socket opened, connection accepted from: ${result['name']}');
          _serverConnection = null; // Will be set when data arrives
          
          onConnection({
            'handle': result['handle'] as int?,
            'address': result['address'] as String?,
            'name': result['name'] as String?,
          });
        }
      } catch (e) {
        print('Platform channel error: $e');
        
        // Fallback: just make device discoverable
        print('Falling back to discoverable mode...');
        bool? isDiscoverable = await _bluetooth.isDiscoverable;
        print('Device discoverable status: $isDiscoverable');
        
        if (isDiscoverable != true) {
          await _bluetooth.requestDiscoverable(300);
          print('Requested discoverability for 300 seconds');
        }
        print('Device is discoverable and waiting for sender connection...');
      }
      
    } catch (e) {
      print('Failed to start listening: $e');
      throw Exception('Failed to start listening: $e');
    }
  }

  static Future<String> getDeviceName() async {
    try {
      String? name = await fbs.FlutterBluetoothSerial.instance.name;
      return name ?? 'Unknown Device';
    } catch (e) {
      return 'Unknown Device';
    }
  }

  Future<void> sendBytes(int handle, Uint8List data) async {
    try {
      // Try server connection first (for receiver sending data back)
      if (_serverConnection != null && _serverConnection!.isConnected) {
        _serverConnection!.output.add(data);
        await _serverConnection!.output.allSent;
        return;
      }
      // Fall back to client connection (for sender)
      if (_connection != null && _connection!.isConnected) {
        _connection!.output.add(data);
        await _connection!.output.allSent;
        return;
      }
      // Last resort: use native socket by handle if provided
      try {
        await platform.invokeMethod('sendBytes', {
          'handle': handle,
          'data': data,
        });
        return;
      } catch (e) {
        throw Exception('Not connected');
      }
    } catch (e) {
      throw Exception('Failed to send data: $e');
    }
  }

  Stream<Uint8List> listenToBytes(int handle) {
    // Prefer native handle stream
    if (handle != -1) {
      return _getStreamForHandle(handle);
    }

    // Fallback to dart-side connections (legacy)
    if (_serverConnection != null && _serverConnection!.isConnected) {
      return _serverConnection!.input ?? const Stream.empty();
    }
    if (_connection != null && _connection!.isConnected) {
      return _connection!.input ?? const Stream.empty();
    }
    return const Stream.empty();
  }

  Future<void> disconnect() async {
    try {
      await _dataSubscription?.cancel();
      _dataSubscription = null;
      await _connection?.close();
      _connection = null;
    } catch (e) {
      print('Disconnect error: $e');
    }
  }
}

class BluetoothDevice {
  final String address;
  final String? name;

  const BluetoothDevice({
    required this.address,
    this.name,
  });
}
