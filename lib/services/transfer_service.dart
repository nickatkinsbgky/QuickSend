import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/device.dart';
import '../models/transfer.dart';

class TransferService {
  static const int defaultPort = 8080;
  HttpServer? _server;
  final StreamController<FileTransfer> _incomingController =
      StreamController<FileTransfer>.broadcast();

  Stream<FileTransfer> get incomingTransfers => _incomingController.stream;

  // List of successfully received files
  final List<FileTransfer> receivedFiles = [];

  // Pending acceptance completers keyed by transfer id
  final Map<String, Completer<bool>> _pendingAcceptances = {};

  /// Start a simple HTTP server to receive files.
  Future<void> startReceiver() async {
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, defaultPort);
      _server!.listen((request) async {
        if (request.method == 'POST' && request.uri.path == '/upload') {
          final fileName = request.headers.value('x-filename') ??
              request.headers.value('filename') ??
              'received_${DateTime.now().millisecondsSinceEpoch}';

          final transferId = DateTime.now().millisecondsSinceEpoch.toString();
          final transfer = FileTransfer(
            id: transferId,
            fileName: fileName,
            fileSize: request.contentLength,
            peer: NearbyDevice(
              id: 'incoming',
              name: request.connectionInfo?.remoteAddress.address ?? 'Unknown',
              address: request.connectionInfo?.remoteAddress.address ?? '',
              port: 0,
            ),
            isOutgoing: false,
            status: TransferStatus.pending,
            progress: 0.0,
          );
          _incomingController.add(transfer);

          // Wait for user acceptance
          final completer = Completer<bool>();
          _pendingAcceptances[transferId] = completer;
          final accepted = await completer.future.timeout(
            const Duration(seconds: 30),
            onTimeout: () => false,
          );
          _pendingAcceptances.remove(transferId);

          if (!accepted) {
            transfer.status = TransferStatus.rejected;
            _incomingController.add(transfer);
            request.response.statusCode = 403;
            await request.response.close();
            return;
          }

          try {
            transfer.status = TransferStatus.inProgress;
            transfer.progress = 0.1;
            _incomingController.add(transfer);

            final dir = await getApplicationDocumentsDirectory();
            final file = File('${dir.path}/$fileName');
            final sink = file.openWrite();

            // Simple progress simulation while piping (real progress would need chunked tracking)
            await request.pipe(sink);
            await sink.close();

            transfer.progress = 1.0;
            transfer.status = TransferStatus.completed;
            receivedFiles.add(transfer);
            _incomingController.add(transfer);
            request.response.statusCode = 200;
          } catch (e) {
            transfer.status = TransferStatus.failed;
            _incomingController.add(transfer);
            request.response.statusCode = 500;
          }
          await request.response.close();
        } else {
          request.response.statusCode = 404;
          await request.response.close();
        }
      });
    } catch (e) {
      print('Failed to start receiver: $e');
    }
  }

  /// Called by UI when user accepts or rejects an incoming transfer.
  void respondToTransfer(String transferId, bool accepted) {
    final completer = _pendingAcceptances[transferId];
    if (completer != null && !completer.isCompleted) {
      completer.complete(accepted);
    }
  }

  Future<void> stopReceiver() async {
    await _server?.close();
    _server = null;
  }

  /// Send a file to a peer (basic HTTP POST).
  Future<FileTransfer> sendFile({
    required NearbyDevice peer,
    required String filePath,
    required String fileName,
    void Function(double)? onProgress,
  }) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final uri = Uri.parse('http://${peer.address}:${peer.port}/upload');

    final request = http.MultipartRequest('POST', uri)
      ..headers['x-filename'] = fileName
      ..fields['filename'] = fileName
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));

    final transfer = FileTransfer(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fileName: fileName,
      fileSize: bytes.length,
      peer: peer,
      isOutgoing: true,
      status: TransferStatus.inProgress,
      progress: 0.0,
    );

    try {
      onProgress?.call(0.2);
      final response = await request.send();
      onProgress?.call(0.8);
      transfer.status = response.statusCode == 200
          ? TransferStatus.completed
          : TransferStatus.failed;
      transfer.progress = transfer.status == TransferStatus.completed ? 1.0 : 0.0;
      onProgress?.call(transfer.progress);
    } catch (e) {
      transfer.status = TransferStatus.failed;
      onProgress?.call(0.0);
    }

    return transfer;
  }

  void dispose() {
    stopReceiver();
    _incomingController.close();
  }
}
