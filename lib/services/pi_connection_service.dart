import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/sensor_data.dart';

// BLE UUIDs — must match your Pi's BLE server config
const String kServiceUuid = '12345678-1234-1234-1234-123456789abc';
const String kCharacteristicUuid = '87654321-4321-4321-4321-cba987654321';

enum ConnectionMode { none, wifi, bluetooth }

enum PiConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
  error,
}

class PiConnectionService extends ChangeNotifier {
  ConnectionMode _mode = ConnectionMode.none;

  PiConnectionState _state = PiConnectionState.disconnected;

  String _statusMessage = 'Not connected';
  String _errorMessage = '';

  // WiFi
  WebSocketChannel? _wsChannel;
  String _wifiHost = '192.168.1.100';
  int _wifiPort = 8000;

  // Bluetooth
  BluetoothDevice? _bleDevice;
  BluetoothCharacteristic? _bleCharacteristic;
  StreamSubscription? _bleSubscription;
  List<ScanResult> _scanResults = [];

  // Data stream
  final StreamController<SensorData> _dataController =
      StreamController<SensorData>.broadcast();

  // Getters
  ConnectionMode get mode => _mode;

  PiConnectionState get state => _state;

  String get statusMessage => _statusMessage;

  String get errorMessage => _errorMessage;

  bool get isConnected => _state == PiConnectionState.connected;

  List<ScanResult> get scanResults => _scanResults;

  Stream<SensorData> get dataStream => _dataController.stream;

  String get wifiHost => _wifiHost;

  int get wifiPort => _wifiPort;

  void setWifiHost(String host) {
    _wifiHost = host;
  }

  void setWifiPort(int port) {
    _wifiPort = port;
  }

  // ─────────────────────────────────────────
  // WiFi / WebSocket
  // ─────────────────────────────────────────

  Future<void> connectWifi() async {
    _setState(PiConnectionState.connecting);

    _setStatus('Connecting via WiFi…');

    try {
      final uri = Uri.parse('ws://$_wifiHost:$_wifiPort/ws');

      _wsChannel = WebSocketChannel.connect(uri);

      await _wsChannel!.ready;

      _mode = ConnectionMode.wifi;

      _setState(PiConnectionState.connected);

      _setStatus('Connected via WiFi to $_wifiHost');

      _wsChannel!.stream.listen(
        (data) => _handleRawData(data as String),
        onError: (e) {
          _setError('WiFi error: $e');
          disconnect();
        },
        onDone: () {
          if (_state == PiConnectionState.connected) {
            _setError('WiFi connection closed by server');
            disconnect();
          }
        },
      );
    } catch (e) {
      _setError('Could not connect: $e');
    }
  }

  // ─────────────────────────────────────────
  // Bluetooth BLE
  // ─────────────────────────────────────────

  Future<void> startBleScan() async {
    _scanResults = [];

    _setState(PiConnectionState.scanning);

    _setStatus('Scanning for Bluetooth devices…');

    notifyListeners();

    final isOn = await FlutterBluePlus.adapterState.first;

    if (isOn != BluetoothAdapterState.on) {
      _setError('Bluetooth is off. Please enable it.');
      return;
    }

    FlutterBluePlus.scanResults.listen((results) {
      _scanResults = results
          .where((r) => r.device.platformName.isNotEmpty)
          .toList()
        ..sort((a, b) => b.rssi.compareTo(a.rssi));

      notifyListeners();
    });

    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 10),
      withServices: [],
    );

    await Future.delayed(const Duration(seconds: 10));

    _setState(PiConnectionState.disconnected);

    _setStatus('Scan complete. ${_scanResults.length} devices found.');
  }

  Future<void> connectBle(BluetoothDevice device) async {
    await FlutterBluePlus.stopScan();

    _setState(PiConnectionState.connecting);

    _setStatus('Connecting to ${device.platformName}…');

    try {
      await device.connect(
        timeout: const Duration(seconds: 10),
      );

      _bleDevice = device;

      final services = await device.discoverServices();

      BluetoothCharacteristic? found;

      for (final s in services) {
        if (s.uuid.toString().toLowerCase() ==
            kServiceUuid.toLowerCase()) {
          for (final c in s.characteristics) {
            if (c.uuid.toString().toLowerCase() ==
                kCharacteristicUuid.toLowerCase()) {
              found = c;
              break;
            }
          }
        }
      }

      if (found == null) {
        _setError('ForceTrack service not found on device.');

        await device.disconnect();

        return;
      }

      _bleCharacteristic = found;

      await found.setNotifyValue(true);

      _bleSubscription = found.lastValueStream.listen((bytes) {
        if (bytes.isNotEmpty) {
          _handleRawData(utf8.decode(bytes));
        }
      });

      device.connectionState.listen((s) {
        if (s == BluetoothConnectionState.disconnected) {
          if (_state == PiConnectionState.connected) {
            _setError('Bluetooth disconnected');
            disconnect();
          }
        }
      });

      _mode = ConnectionMode.bluetooth;

      _setState(PiConnectionState.connected);

      _setStatus(
        'Connected via Bluetooth to ${device.platformName}',
      );
    } catch (e) {
      _setError('BLE connect failed: $e');
    }
  }

  // ─────────────────────────────────────────
  // Shared
  // ─────────────────────────────────────────

  void _handleRawData(String raw) {
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;

      final data = SensorData.fromJson(json);

      _dataController.add(data);
    } catch (e) {
      debugPrint('Parse error: $e');
    }
  }

  Future<void> disconnect() async {
    await _wsChannel?.sink.close();

    _wsChannel = null;

    await _bleSubscription?.cancel();

    _bleSubscription = null;

    await _bleDevice?.disconnect();

    _bleDevice = null;

    _bleCharacteristic = null;

    _mode = ConnectionMode.none;

    _setState(PiConnectionState.disconnected);

    _setStatus('Disconnected');
  }

  void _setState(PiConnectionState s) {
    _state = s;

    _errorMessage = '';

    notifyListeners();
  }

  void _setStatus(String msg) {
    _statusMessage = msg;

    notifyListeners();
  }

  void _setError(String msg) {
    _state = PiConnectionState.error;

    _errorMessage = msg;

    _statusMessage = 'Error';

    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();

    _dataController.close();

    super.dispose();
  }
}