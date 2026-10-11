import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/device.dart';
import '../models/transfer.dart';
import '../services/discovery_service.dart';
import '../services/transfer_service.dart';
import '../widgets/device_card.dart';
import 'transfer_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DiscoveryService _discovery = DiscoveryService();
  final TransferService _transferService = TransferService();
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
    _transferService.startReceiver();

    // Listen for incoming transfers
    _transferService.incomingTransfers.listen((transfer) {
      if (mounted && transfer.status == TransferStatus.completed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Received: ${transfer.fileName}')),
        );
      }
    });
  }

  @override
  void dispose() {
    _discovery.dispose();
    _transferService.dispose();
    super.dispose();
  }

  Future<void> _pickAndSend() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.path == null) return;

    if (_devices.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No nearby devices found')),
        );
      }
      return;
    }

    final device = _devices.first;
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TransferScreen(
            device: device,
            filePath: file.path!,
            fileName: file.name,
          ),
        ),
      );
    }
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
                  onTap: () async {
                    final result = await FilePicker.platform.pickFiles();
                    if (result == null || result.files.isEmpty) return;
                    final file = result.files.first;
                    if (file.path == null || !mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TransferScreen(
                          device: device,
                          filePath: file.path!,
                          fileName: file.name,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickAndSend,
        icon: const Icon(Icons.send),
        label: const Text('Send'),
      ),
    );
  }
}
