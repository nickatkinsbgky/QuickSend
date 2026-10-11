import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/device.dart';
import '../models/transfer.dart';

class TransferService {
  static const int defaultPort = 8080;
  // Custom BLE service and characteristic UUIDs for QuickSend
  static const String quickSendServiceUuid = '12345678-1234-5678-1234-56789abcdef0';
  static const String fileTransferCharUuid = '12345678-1234-5678-1234-56789abcdef1';

  HttpServer? _server;
  final StreamController<FileTransfer> _incomingController =
      StreamController<FileTransfer>.broadcast();

  Stream<FileTransfer> get incomingTransfers => _incomingController.stream;

  final List<FileTransfer> receivedFiles = [];
  final Map<String, Completer<bool>> _pendingAcceptances = {};

  /// Start a simple HTTP server to receive files (Wi-Fi).
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

  /// Send a file over Wi-Fi (HTTP).
  Future<FileTransfer> sendFile({
    required NearbyDevice peer,
    required String filePath,
    required String fileName,
    void Function(double)? onProgress,
  }) async {
    // If this is a Bluetooth device (port == 0 and platform contains Bluetooth), use BLE
    if (peer.port == 0 && peer.platform.toLowerCase().contains('bluetooth')) {
      return _sendFileOverBluetooth(
        peer: peer,
        filePath: filePath,
        fileName: fileName,
        onProgress: onProgress,
      );
    }

    // Default: Wi-Fi HTTP
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

  /// Send a file over Bluetooth Low Energy.
  Future<FileTransfer> _sendFileOverBluetooth({
    required NearbyDevice peer,
    required String filePath,
    required String fileName,
    void Function(double)? onProgress,
  }) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();

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
      onProgress?.call(0.1);

      // Find the device by remote ID
      final device = BluetoothDevice.fromId(peer.address);
      await device.connect(timeout: const Duration(seconds: 10));
      onProgress?.call(0.3);

      // Discover services
      final services = await device.discoverServices();
      BluetoothCharacteristic? transferChar;

      for (final service in services) {
        if (service.uuid.str.toLowerCase() == quickSendServiceUuid.toLowerCase()) {
          for (final char in service.characteristics) {
            if (char.uuid.str.toLowerCase() == fileTransferCharUuid.toLowerCase()) {
              transferChar = char;
              break;
            }
          }
        }
      }

      if (transferChar == null) {
        throw Exception('QuickSend transfer characteristic not found');
      }

      // Write file data in chunks (BLE MTU is typically ~20-512 bytes)
      const chunkSize = 180;
      for (int i = 0; i < bytes.length; i += chunkSize) {
        final end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
        final chunk = bytes.sublist(i, end);
        await transferChar.write(chunk, withoutResponse: false);
        final progress = (i + chunk.length) / bytes.length;
        transfer.progress = progress;
        onProgress?.call(progress);
      }

      await device.disconnect();
      transfer.status = TransferStatus.completed;
      transfer.progress = 1.0;
      onProgress?.call(1.0);
    } catch (e) {
      transfer.status = TransferStatus.failed;
      onProgress?.call(0.0);
      print('Bluetooth send error: $e');
    }

    return transfer;
  }

  void dispose() {
    stopReceiver();
    _incomingController.close();
  }
}
