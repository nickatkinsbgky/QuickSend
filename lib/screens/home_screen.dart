import 'package:flutter/material.dart';
import '../models/device.dart';
import '../services/discovery_service.dart';
import '../widgets/device_card.dart';
import 'transfer_screen.dart';

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
      if (mounted) {
        setState(() => _devices = devices);
      }
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
      appBar: AppBar(
        title: const Text('QuickSend'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Restart discovery
              _discovery.stopDiscovery().then((_) => _discovery.startDiscovery());
            },
          ),
        ],
      ),
      body: _devices.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Looking for nearby devices...'),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _devices.length,
              itemBuilder: (context, index) {
                final device = _devices[index];
                return DeviceCard(
                  device: device,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TransferScreen(device: device),
                      ),
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: Open file picker and show device selection
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File picker coming next')),
          );
        },
        icon: const Icon(Icons.send),
        label: const Text('Send'),
      ),
    );
  }
}
