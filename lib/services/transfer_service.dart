import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/device.dart';
import '../models/transfer.dart';

class TransferService {
  static const int defaultPort = 8080;
  HttpServer? _server;
  final StreamController<FileTransfer> _incomingController =
      StreamController<FileTransfer>.broadcast();

  Stream<FileTransfer> get incomingTransfers => _incomingController.stream;

  /// Start a simple HTTP server to receive files.
  Future<void> startReceiver() async {
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, defaultPort);
      _server!.listen((request) async {
        if (request.method == 'POST' && request.uri.path == '/upload') {
          // TODO: Parse multipart or raw body, save file, emit FileTransfer
          final transfer = FileTransfer(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            fileName: request.headers.value('x-filename') ?? 'unknown',
            fileSize: request.contentLength,
            peer: NearbyDevice(
              id: 'incoming',
              name: request.connectionInfo?.remoteAddress.address ?? 'Unknown',
              address: request.connectionInfo?.remoteAddress.address ?? '',
              port: 0,
            ),
            isOutgoing: false,
            status: TransferStatus.inProgress,
          );
          _incomingController.add(transfer);
          // Drain the request body for now
          await request.drain();
          request.response.statusCode = 200;
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

  Future<void> stopReceiver() async {
    await _server?.close();
    _server = null;
  }

  /// Send a file to a peer (basic HTTP POST skeleton).
  Future<FileTransfer> sendFile({
    required NearbyDevice peer,
    required String filePath,
    required String fileName,
  }) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final uri = Uri.parse('http://${peer.address}:${peer.port}/upload');

    final request = http.MultipartRequest('POST', uri)
      ..fields['filename'] = fileName
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));

    final transfer = FileTransfer(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fileName: fileName,
      fileSize: bytes.length,
      peer: peer,
      isOutgoing: true,
      status: TransferStatus.inProgress,
    );

    try {
      final response = await request.send();
      transfer.status = response.statusCode == 200
          ? TransferStatus.completed
          : TransferStatus.failed;
    } catch (e) {
      transfer.status = TransferStatus.failed;
    }

    return transfer;
  }

  void dispose() {
    stopReceiver();
    _incomingController.close();
  }
}
