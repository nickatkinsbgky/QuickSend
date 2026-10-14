import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/device.dart';
import '../models/transfer.dart';
import '../services/discovery_service.dart';
import '../services/transfer_service.dart';
import '../widgets/device_card.dart';
import '../widgets/file_thumbnail.dart';
import 'share_link_screen.dart';
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
    _discovery.start();
    _transferService.startReceiver();

    _transferService.incomingTransfers.listen((transfer) {
      if (!mounted) return;
      if (transfer.status == TransferStatus.pending) {
        _showAcceptDialog(transfer);
      } else if (transfer.status == TransferStatus.completed && !transfer.isOutgoing) {
        setState(() => _received = List.from(_transferService.receivedFiles));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Received: ${transfer.fileName}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    });
  }

  Future<void> _showAcceptDialog(FileTransfer transfer) async {
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Incoming File', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FileThumbnail(fileName: transfer.fileName, size: 80),
            const SizedBox(height: 16),
            Text(
              '${transfer.peer.name} wants to send',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '"${transfer.fileName}"',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              _formatSize(transfer.fileSize),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Reject', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          FilledButton(
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

  Future<void> _shareViaLink() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );
    if (result == null || result.files.isEmpty) return;

    final files = result.files.where((f) => f.path != null).toList();
    if (files.isEmpty) return;

    final fileMaps = files
        .map((f) => {'path': f.path!, 'name': f.name})
        .toList();

    final url = await _transferService.createShareLink(fileMaps);

    if (url != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ShareLinkScreen(
            url: url,
            fileNames: files.map((f) => f.name).toList(),
          ),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not create share link. Make sure you are on Wi-Fi.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _pickAndSend([NearbyDevice? targetDevice]) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );
    if (result == null || result.files.isEmpty) return;

    final files = result.files.where((f) => f.path != null).toList();
    if (files.isEmpty) return;

    if (_devices.isEmpty) {
      await _shareViaLink();
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
            ),
          ),
        ),
        title: const Text('QuickSend'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              _discovery.stop().then((_) => _discovery.start());
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 100), // space for extended AppBar
          if (_devices.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Text(
                'Nearby devices',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.blueGrey.shade700,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          Expanded(
            child: _devices.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.radar, size: 72, color: Colors.blue.shade200),
                        const SizedBox(height: 24),
                        Text(
                          'Looking for nearby devices...',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            'Or send a link so anyone on the same Wi-Fi can download without the app.',
                            style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 28),
                        const CircularProgressIndicator(strokeWidth: 3),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 4, bottom: 100),
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
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Text(
                'Received Files',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            SizedBox(
              height: 130,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: _received.length,
                itemBuilder: (context, index) {
                  final file = _received[index];
                  return ListTile(
                    leading: FileThumbnail(fileName: file.fileName, size: 44),
                    title: Text(file.fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(_formatSize(file.fileSize)),
                    dense: true,
                  );
                },
              ),
            ),
          ],
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            onPressed: _shareViaLink,
            icon: const Icon(Icons.link),
            label: const Text('Share Link'),
            heroTag: 'shareLink',
            elevation: 6,
          ),
          const SizedBox(height: 16),
          FloatingActionButton.extended(
            onPressed: () => _pickAndSend(),
            icon: const Icon(Icons.send),
            label: const Text('Send'),
            heroTag: 'send',
            elevation: 8,
          ),
        ],
      ),
    );
  }
}
