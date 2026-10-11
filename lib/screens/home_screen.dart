import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/device.dart';
import '../models/transfer.dart';
import '../services/discovery_service.dart';
import '../services/transfer_service.dart';
import '../widgets/device_card.dart';
import '../widgets/file_thumbnail.dart';
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FileThumbnail(fileName: transfer.fileName, size: 80),
            const SizedBox(height: 12),
            Text(
              '${transfer.peer.name} wants to send\n"${transfer.fileName}"\n(${_formatSize(transfer.fileSize)})',
              textAlign: TextAlign.center,
            ),
          ],
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

  Future<void> _pickAndSend([NearbyDevice? targetDevice]) async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null || result.files.isEmpty) return;

    final files = result.files.where((f) => f.path != null).toList();
    if (files.isEmpty) return;

    if (_devices.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No nearby devices found')),
        );
      }
      return;
    }

    final device = targetDevice ?? _devices.first;
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TransferScreen(
            device: device,
            files: files.map((f) => {'path': f.path!, 'name': f.name}).toList(),
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
                        SizedBox(height: 8),
                        Text(
                          'Wi-Fi and Bluetooth \u2022 Phones, tablets, and PCs',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _devices.length,
                    itemBuilder: (context, index) {
                      final device = _devices[index];
                      return DeviceCard(
                        device: device,
                        onTap: () => _pickAndSend(device),
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
              height: 140,
              child: ListView.builder(
                itemCount: _received.length,
                itemBuilder: (context, index) {
                  final file = _received[index];
                  return ListTile(
                    leading: FileThumbnail(
                      fileName: file.fileName,
                      size: 48,
                    ),
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
        onPressed: () => _pickAndSend(),
        icon: const Icon(Icons.send),
        label: const Text('Send'),
      ),
    );
  }
}
