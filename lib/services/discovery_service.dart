import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:nsd/nsd.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/device.dart';

class DiscoveryService {
  static const String serviceType = '_quicksend._tcp';
  static const String serviceName = 'QuickSend';

  final StreamController<List<NearbyDevice>> _devicesController =
      StreamController<List<NearbyDevice>>.broadcast();

  Stream<List<NearbyDevice>> get devicesStream => _devicesController.stream;

  final List<NearbyDevice> _wifiDevices = [];
  final List<NearbyDevice> _bluetoothDevices = [];

  Discovery? _wifiDiscovery;
  Registration? _wifiRegistration;
  StreamSubscription? _btSubscription;
  Timer? _btRestartTimer;

  String get _currentPlatform {
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isLinux) return 'Linux';
    return 'Unknown';
  }

  Future<void> start() async {
    await _requestPermissions();
    await _startWifi();
    await _startBluetooth();
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ].request();
    } else if (Platform.isIOS) {
      await Permission.bluetooth.request();
    }
  }

  Future<void> _startWifi() async {
    try {
      final encoder = const Utf8Encoder();

      _wifiRegistration = await register(
        Service(
          name: '$serviceName-${_currentPlatform}',
          type: serviceType,
          port: 8080,
          txt: {
            'platform': encoder.convert(_currentPlatform),
            'app': encoder.convert('QuickSend'),
          },
        ),
      );

      _wifiDiscovery = await startDiscovery(serviceType);
      _wifiDiscovery!.addListener(_onWifiUpdate);
      _onWifiUpdate();
    } catch (e) {
      print('Wi-Fi discovery error: $e');
    }
  }

  void _onWifiUpdate() {
    final services = _wifiDiscovery?.services ?? [];
    _wifiDevices.clear();

    for (final service in services) {
      if (service.name == null || service.host == null || service.port == null) {
        continue;
      }

      String platform = 'Unknown';
      final platformBytes = service.txt?['platform'];
      if (platformBytes != null) {
        try {
          platform = utf8.decode(platformBytes);
        } catch (_) {}
      }

      _wifiDevices.add(
        NearbyDevice(
          id: 'wifi_${service.name}',
          name: service.name!,
          address: service.host!,
          port: service.port!,
          platform: '$platform (Wi-Fi)',
        ),
      );
    }

    _emit();
  }

  Future<void> _startBluetooth() async {
    try {
      // Wait until Bluetooth is on
      await FlutterBluePlus.adapterState
          .where((s) => s == BluetoothAdapterState.on)
          .first
          .timeout(const Duration(seconds: 10));

      // Start continuous scanning by restarting periodically
      _startBleScan();
    } catch (e) {
      print('Bluetooth discovery error: $e');
    }
  }

  void _startBleScan() {
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 30));

    _btSubscription?.cancel();
    _btSubscription = FlutterBluePlus.scanResults.listen((results) {
      _bluetoothDevices.clear();

      for (final result in results) {
        final name = result.device.platformName.isNotEmpty
            ? result.device.platformName
            : result.device.remoteId.str;

        // Show devices with decent signal (less strict filter)
        if (result.rssi > -90) {
          _bluetoothDevices.add(
            NearbyDevice(
              id: 'ble_${result.device.remoteId.str}',
              name: name,
              address: result.device.remoteId.str,
              port: 0,
              platform: 'Bluetooth',
            ),
          );
        }
      }

      _emit();
    });

    // Restart scan every 30 seconds so it keeps looking
    _btRestartTimer?.cancel();
    _btRestartTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      FlutterBluePlus.startScan(timeout: const Duration(seconds: 30));
    });
  }

  void _emit() {
    final combined = [..._wifiDevices, ..._bluetoothDevices];
    final unique = <String, NearbyDevice>{};
    for (final d in combined) {
      unique[d.id] = d;
    }
    _devicesController.add(unique.values.toList());
  }

  Future<void> stop() async {
    _btRestartTimer?.cancel();
    _btRestartTimer = null;

    if (_wifiDiscovery != null) {
      _wifiDiscovery!.removeListener(_onWifiUpdate);
      await stopDiscovery(_wifiDiscovery!);
      _wifiDiscovery = null;
    }

    if (_wifiRegistration != null) {
      await unregister(_wifiRegistration!);
      _wifiRegistration = null;
    }

    await FlutterBluePlus.stopScan();
    await _btSubscription?.cancel();
    _btSubscription = null;
  }

  void dispose() {
    stop();
    _devicesController.close();
  }
}
