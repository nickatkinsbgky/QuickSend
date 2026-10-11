import 'dart:async';
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

  Future<void> startDiscovery() async {
    try {
      // Register our own service so others can find us
      _registration = await register(
        const Service(
          name: serviceName,
          type: serviceType,
          port: 8080, // Default transfer port
        ),
      );

      // Start discovering other devices
      _discovery = await startDiscovery(serviceType);
      _discovery!.addListener(_onDiscoveryUpdate);
      _onDiscoveryUpdate(); // Initial update
    } catch (e) {
      // Handle permission or platform errors
      print('Discovery error: $e');
    }
  }

  void _onDiscoveryUpdate() {
    final services = _discovery?.services ?? [];
    _devices.clear();
    for (final service in services) {
      if (service.name != null && service.host != null && service.port != null) {
        _devices.add(NearbyDevice(
          id: service.name!,
          name: service.name!,
          address: service.host!,
          port: service.port!,
          platform: 'Unknown', // Could be enriched from TXT records later
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
