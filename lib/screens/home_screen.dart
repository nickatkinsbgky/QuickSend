import 'package:flutter/material.dart';
import '../models/device.dart';
import '../services/discovery_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DiscoveryService _discovery = DiscoveryService();
  List<NearbyDevice> _devices = [];

  @override
  void initState() {
    super.initState();
    _discovery.devicesStream.listen((devices) {
      setState(() => _devices = devices);
    });
    _discovery.startDiscovery();
  }

  @override
  void dispose() {
    _discovery.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QuickSend')),
      body: _devices.isEmpty
          ? const Center(child: Text('Looking for nearby devices...'))
          : ListView.builder(
              itemCount: _devices.length,
              itemBuilder: (context, index) {
                final device = _devices[index];
                return ListTile(
                  leading: const Icon(Icons.devices),
                  title: Text(device.name),
                  subtitle: Text('${device.address}:${device.port}'),
                  onTap: () {
                    // TODO: Navigate to file picker / transfer screen
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Open file picker to send
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
