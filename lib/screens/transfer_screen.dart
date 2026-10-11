import 'package:flutter/material.dart';
import '../models/device.dart';
import '../models/transfer.dart';
import '../services/transfer_service.dart';
import '../widgets/file_thumbnail.dart';

class TransferScreen extends StatefulWidget {
  final NearbyDevice device;
  final List<Map<String, String>> files;

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
    final isComplete = _currentIndex >= widget.files.length && !_sending;

    return Scaffold(
      appBar: AppBar(
        title: Text('Send to ${widget.device.name}'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!isComplete && currentFile != null) ...[
                FileThumbnail(
                  filePath: currentFile['path'],
                  fileName: currentFile['name']!,
                  size: 120,
                ),
                const SizedBox(height: 20),
                Text(
                  currentFile['name']!,
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  'File ${_currentIndex + 1} of ${widget.files.length}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                ),
              ],
              const SizedBox(height: 32),
              if (_sending) ...[
                SizedBox(
                  width: double.infinity,
                  child: LinearProgressIndicator(
                    value: _progress > 0 ? _progress : null,
                    borderRadius: BorderRadius.circular(4),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Sending... ${(_progress * 100).toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ] else if (_error != null) ...[
                Icon(Icons.error_outline, color: Colors.red.shade400, size: 64),
                const SizedBox(height: 16),
                Text(
                  'Transfer failed',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
                const SizedBox(height: 24),
                FilledButton(onPressed: _sendNext, child: const Text('Retry')),
              ] else if (isComplete) ...[
                Icon(
                  _successCount == widget.files.length
                      ? Icons.check_circle_outline
                      : Icons.info_outline,
                  color: _successCount == widget.files.length
                      ? Colors.green.shade600
                      : Colors.orange.shade600,
                  size: 72,
                ),
                const SizedBox(height: 20),
                Text(
                  _successCount == widget.files.length
                      ? 'All files sent'
                      : '$_successCount of ${widget.files.length} files sent',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
