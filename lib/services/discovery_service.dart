import 'dart:async';
import 'dart:io';
import 'package:nsd/nsd.dart';
import '../models/device.dart';

class DiscoveryService {
  static const String serviceType = '_quicksend._tcp';
  static const String serviceName = 'QuickSend';

  final StreamController<List<NearbyDevice>> _devicesController =
      StreamController<List<NearbyDevice>>.broadcast();

  Stream<List<NearbyDevice>> get devicesStream => _devicesController.stream;
  final List<NearbyDevice> _devices = [];

  Discovery? _discovery;
  Registration? _registration;

  String get _currentPlatform {
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isLinux) return 'Linux';
    return 'Unknown';
  }

  Future<void> startDiscovery() async {
    try {
      // Register our own service so others can find us (phones, tablets, and PCs)
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

      // Start discovering other devices on the local network
      _discovery = await startDiscovery(serviceType);
      _discovery!.addListener(_onDiscoveryUpdate);
      _onDiscoveryUpdate();
    } catch (e) {
      print('Discovery error: $e');
    }
  }

  void _onDiscoveryUpdate() {
    final services = _discovery?.services ?? [];
    _devices.clear();
    for (final service in services) {
      if (service.name != null && service.host != null && service.port != null) {
        final platform = service.txt?['platform'] ?? 'Unknown';
        _devices.add(NearbyDevice(
          id: service.name!,
          name: service.name!,
          address: service.host!,
          port: service.port!,
          platform: platform,
        ));
      }
    }
    _devicesController.add(List.from(_devices));
  }

  Future<void> stopDiscovery() async {
    if (_discovery != null) {
      _discovery!.removeListener(_onDiscoveryUpdate);
      await stopDiscovery(_discovery!);
      _discovery = null;
    }
    if (_registration != null) {
      await unregister(_registration!);
      _registration = null;
    }
  }

  void dispose() {
    stopDiscovery();
    _devicesController.close();
  }
}
