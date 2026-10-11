import 'package:flutter/material.dart';
import '../models/device.dart';
import '../models/transfer.dart';
import '../services/transfer_service.dart';
import '../widgets/file_thumbnail.dart';

class TransferScreen extends StatefulWidget {
  final NearbyDevice device;
  final List<Map<String, String>> files; // [{path, name}, ...]

  const TransferScreen({
    super.key,
    required this.device,
    required this.files,
  });

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final TransferService _transferService = TransferService();
  int _currentIndex = 0;
  bool _sending = false;
  double _progress = 0.0;
  String? _error;
  int _successCount = 0;

  @override
  void initState() {
    super.initState();
    _sendNext();
  }

  Future<void> _sendNext() async {
    if (_currentIndex >= widget.files.length) {
      setState(() => _sending = false);
      return;
    }

    final file = widget.files[_currentIndex];
    setState(() {
      _sending = true;
      _error = null;
      _progress = 0.0;
    });

    try {
      final result = await _transferService.sendFile(
        peer: widget.device,
        filePath: file['path']!,
        fileName: file['name']!,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );

      if (result.status == TransferStatus.completed) {
        _successCount++;
      }

      if (mounted) {
        setState(() {
          _currentIndex++;
          _sending = _currentIndex < widget.files.length;
        });
        if (_currentIndex < widget.files.length) {
          await _sendNext();
        }
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
    final currentFile = _currentIndex < widget.files.length
        ? widget.files[_currentIndex]
        : null;

    return Scaffold(
      appBar: AppBar(title: Text('Send to ${widget.device.name}')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Sending ${_currentIndex + 1} of ${widget.files.length}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              if (currentFile != null) ...[
                FileThumbnail(
                  filePath: currentFile['path'],
                  fileName: currentFile['name']!,
                  size: 100,
                ),
                const SizedBox(height: 12),
                Text(currentFile['name']!, textAlign: TextAlign.center),
              ],
              const SizedBox(height: 24),
              if (_sending) ...[
                LinearProgressIndicator(value: _progress > 0 ? _progress : null),
                const SizedBox(height: 12),
                Text('Sending... ${(_progress * 100).toStringAsFixed(0)}%'),
              ] else if (_error != null) ...[
                const Icon(Icons.error, color: Colors.red, size: 48),
                const SizedBox(height: 12),
                Text('Failed: $_error', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                ElevatedButton(onPressed: _sendNext, child: const Text('Retry')),
              ] else ...[
                Icon(
                  _successCount == widget.files.length ? Icons.check_circle : Icons.info,
                  color: _successCount == widget.files.length ? Colors.green : Colors.orange,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  '$_successCount of ${widget.files.length} files sent',
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
