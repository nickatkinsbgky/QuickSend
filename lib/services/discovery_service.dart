import 'dart:async';
import 'dart:io';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/device.dart';

class DiscoveryService {
  final StreamController<List<NearbyDevice>> _devicesController =
      StreamController<List<NearbyDevice>>.broadcast();

  Stream<List<NearbyDevice>> get devicesStream => _devicesController.stream;
  final List<NearbyDevice> _bluetoothDevices = [];

  StreamSubscription? _scanSubscription;

  Future<void> startDiscovery() async {
    await _startBluetoothDiscovery();
  }

  Future<void> _startBluetoothDiscovery() async {
    try {
      await FlutterBluePlus.adapterState.where((s) => s == BluetoothAdapterState.on).first;

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        _bluetoothDevices.clear();
        for (final result in results) {
          final name = result.device.platformName.isNotEmpty
              ? result.device.platformName
              : result.device.remoteId.str;
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
        _devicesController.add(List.from(_bluetoothDevices));
      });
    } catch (e) {
      print('Bluetooth discovery error: $e');
    }
  }

  Future<void> stop() async {
    await FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();
    _scanSubscription = null;
  }

  void dispose() {
    stop();
    _devicesController.close();
  }
}
