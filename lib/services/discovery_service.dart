import 'dart:async';
import 'dart:io';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:nsd/nsd.dart';
import '../models/device.dart';

class DiscoveryService {
  static const String serviceType = '_quicksend._tcp';
  static const String serviceName = 'QuickSend';

  final StreamController<List<NearbyDevice>> _devicesController =
      StreamController<List<NearbyDevice>>.broadcast();

  Stream<List<NearbyDevice>> get devicesStream => _devicesController.stream;
  final List<NearbyDevice> _wifiDevices = [];
  final List<NearbyDevice> _bluetoothDevices = [];

  Discovery? _discovery;
  Registration? _registration;
  StreamSubscription? _scanSubscription;

  String get _currentPlatform {
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isLinux) return 'Linux';
    return 'Unknown';
  }

  Future<void> startDiscovery() async {
    await _startWifiDiscovery();
    await _startBluetoothDiscovery();
  }

  Future<void> _startWifiDiscovery() async {
    try {
      _registration = await register(
        Service(
          name: '$serviceName-${_currentPlatform}',
          type: serviceType,
          port: 8080,
          txt: {
            'platform': _currentPlatform,
            'app': 'QuickSend',
          },
        ),
      );

      _discovery = await startDiscovery(serviceType);
      _discovery!.addListener(_onWifiDiscoveryUpdate);
      _onWifiDiscoveryUpdate();
    } catch (e) {
      print('Wi-Fi discovery error: $e');
    }
  }

  void _onWifiDiscoveryUpdate() {
    final services = _discovery?.services ?? [];
    _wifiDevices.clear();
    for (final service in services) {
      if (service.name != null && service.host != null && service.port != null) {
        final platform = service.txt?['platform'] ?? 'Unknown';
        _wifiDevices.add(NearbyDevice(
          id: service.name!,
          name: service.name!,
          address: service.host!,
          port: service.port!,
          platform: '$platform (Wi-Fi)',
        ));
      }
    }
    _emitCombined();
  }

  Future<void> _startBluetoothDiscovery() async {
    try {
      // Request Bluetooth permissions if needed
      await FlutterBluePlus.adapterState.where((s) => s == BluetoothAdapterState.on).first;

      // Start scanning for nearby BLE devices
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        _bluetoothDevices.clear();
        for (final result in results) {
          final name = result.device.platformName.isNotEmpty
              ? result.device.platformName
              : result.device.remoteId.str;
          // Filter for devices that look like QuickSend or just show nearby BLE devices
          if (name.toLowerCase().contains('quicksend') || result.rssi > -80) {
            _bluetoothDevices.add(NearbyDevice(
              id: result.device.remoteId.str,
              name: name,
              address: result.device.remoteId.str,
              port: 0,
              platform: 'Bluetooth',
            ));
          }
        }
        _emitCombined();
      });
    } catch (e) {
      print('Bluetooth discovery error: $e');
    }
  }

  void _emitCombined() {
    final combined = [..._wifiDevices, ..._bluetoothDevices];
    // Deduplicate by id
    final unique = <String, NearbyDevice>{};
    for (final d in combined) {
      unique[d.id] = d;
    }
    _devicesController.add(unique.values.toList());
  }

  Future<void> stopDiscovery() async {
    if (_discovery != null) {
      _discovery!.removeListener(_onWifiDiscoveryUpdate);
      await stopDiscovery(_discovery!);
      _discovery = null;
    }
    if (_registration != null) {
      await unregister(_registration!);
      _registration = null;
    }
    await FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();
    _scanSubscription = null;
  }

  void dispose() {
    stopDiscovery();
    _devicesController.close();
  }
}
