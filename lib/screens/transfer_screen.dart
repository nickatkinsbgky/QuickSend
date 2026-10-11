import 'package:flutter/material.dart';
import '../models/device.dart';
import '../models/transfer.dart';
import '../services/transfer_service.dart';

class TransferScreen extends StatefulWidget {
  final NearbyDevice device;
  final String filePath;
  final String fileName;

  const TransferScreen({
    super.key,
    required this.device,
    required this.filePath,
    required this.fileName,
  });

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final TransferService _transferService = TransferService();
  FileTransfer? _transfer;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startSend();
  }

  Future<void> _startSend() async {
    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      final result = await _transferService.sendFile(
        peer: widget.device,
        filePath: widget.filePath,
        fileName: widget.fileName,
      );
      if (mounted) {
        setState(() {
          _transfer = result;
          _sending = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _sending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Send to ${widget.device.name}')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('File: ${widget.fileName}', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              Text('To: ${widget.device.name} (${widget.device.address})'),
              const SizedBox(height: 32),
              if (_sending) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text('Sending...'),
              ] else if (_error != null) ...[
                const Icon(Icons.error, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text('Failed: $_error', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _startSend, child: const Text('Retry')),
              ] else if (_transfer != null) ...[
                Icon(
                  _transfer!.status == TransferStatus.completed ? Icons.check_circle : Icons.error,
                  color: _transfer!.status == TransferStatus.completed ? Colors.green : Colors.red,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  _transfer!.status == TransferStatus.completed ? 'Sent successfully!' : 'Transfer failed',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
