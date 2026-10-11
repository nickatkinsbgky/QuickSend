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
  List<FileTransfer> _received = [];

  @override
  void initState() {
    super.initState();
    _discovery.devicesStream.listen((devices) {
      if (mounted) setState(() => _devices = devices);
    });
    _discovery.startDiscovery();
    _transferService.startReceiver();

    _transferService.incomingTransfers.listen((transfer) {
      if (!mounted) return;
      if (transfer.status == TransferStatus.pending) {
        _showAcceptDialog(transfer);
      } else if (transfer.status == TransferStatus.completed && !transfer.isOutgoing) {
        setState(() => _received = List.from(_transferService.receivedFiles));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Received: ${transfer.fileName}')),
        );
      }
    });
  }

  Future<void> _showAcceptDialog(FileTransfer transfer) async {
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Incoming File'),
        content: Text(
          '${transfer.peer.name} wants to send\n"${transfer.fileName}"\n(${_formatSize(transfer.fileSize)})',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Reject'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
    _transferService.respondToTransfer(transfer.id, accepted == true);
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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
      body: Column(
        children: [
          Expanded(
            child: _devices.isEmpty
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
          ),
          if (_received.isNotEmpty) ...[
            const Divider(),
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text('Received Files', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            SizedBox(
              height: 120,
              child: ListView.builder(
                itemCount: _received.length,
                itemBuilder: (context, index) {
                  final file = _received[index];
                  return ListTile(
                    leading: const Icon(Icons.insert_drive_file),
                    title: Text(file.fileName),
                    subtitle: Text(_formatSize(file.fileSize)),
                    dense: true,
                  );
                },
              ),
            ),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickAndSend,
        icon: const Icon(Icons.send),
        label: const Text('Send'),
      ),
    );
  }
}
