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
  static const String quickSendServiceUuid = '12345678-1234-5678-1234-56789abcdef0';
  static const String fileTransferCharUuid = '12345678-1234-5678-1234-56789abcdef1';

  HttpServer? _server;
  final StreamController<FileTransfer> _incomingController =
      StreamController<FileTransfer>.broadcast();

  Stream<FileTransfer> get incomingTransfers => _incomingController.stream;

  final List<FileTransfer> receivedFiles = [];
  final Map<String, Completer<bool>> _pendingAcceptances = {};

  // token -> list of {path, name}
  final Map<String, List<Map<String, String>>> _shareLinks = {};

  List<int> _bleBuffer = [];
  String? _currentBleFileName;
  bool _bleFilenameReceived = false;

  Future<void> startReceiver() async {
    await _startHttpReceiver();
    await _startBluetoothReceiver();
  }

  Future<void> _startHttpReceiver() async {
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, defaultPort);
      _server!.listen((request) async {
        if (request.method == 'GET' && request.uri.path.startsWith('/share/')) {
          final segments = request.uri.pathSegments;
          if (segments.length >= 2) {
            final token = segments[1];
            final files = _shareLinks[token];

            if (files != null) {
              // Individual file download: /share/TOKEN/filename
              if (segments.length >= 3) {
                final requestedName = Uri.decodeComponent(segments[2]);
                final match = files.firstWhere(
                  (f) => f['name'] == requestedName,
                  orElse: () => {},
                );
                final filePath = match['path'];
                if (filePath != null && File(filePath).existsSync()) {
                  final file = File(filePath);
                  final lower = requestedName.toLowerCase();
                  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
                    request.response.headers.contentType = ContentType('image', 'jpeg');
                  } else if (lower.endsWith('.png')) {
                    request.response.headers.contentType = ContentType('image', 'png');
                  } else if (lower.endsWith('.gif')) {
                    request.response.headers.contentType = ContentType('image', 'gif');
                  } else if (lower.endsWith('.webp')) {
                    request.response.headers.contentType = ContentType('image', 'webp');
                  } else {
                    request.response.headers.contentType = ContentType.binary;
                  }
                  request.response.headers.add(
                    'Content-Disposition',
                    'attachment; filename="$requestedName"',
                  );
                  await request.response.addStream(file.openRead());
                  await request.response.close();
                  return;
                }
              }

              // List page: /share/TOKEN
              final html = _buildSharePage(token, files);
              request.response.headers.contentType = ContentType.html;
              request.response.write(html);
              await request.response.close();
              return;
            }
          }

          request.response.statusCode = 404;
          await request.response.close();
          return;
        }

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
            await sink.addStream(request);
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
      print('Failed to start HTTP receiver: $e');
    }
  }

  String _buildSharePage(String token, List<Map<String, String>> files) {
    final items = files.map((f) {
      final name = f['name'] ?? 'file';
      final encoded = Uri.encodeComponent(name);
      final lower = name.toLowerCase();
      final isImage = lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png') || lower.endsWith('.heic') || lower.endsWith('.gif') || lower.endsWith('.webp');
      final badge = isImage ? ' <span style="color:#2e7d32;font-size:12px">(Photo)</span>' : '';
      return '<li style="margin:12px 0"><a href="/share/$token/$encoded" download="$name" style="font-size:18px;color:#1565c0;text-decoration:none">$name$badge</a></li>';
    }).join();

    final fileListJson = files.map((f) => '"${Uri.encodeComponent(f['name'] ?? 'file')}"').join(',');

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>QuickSend</title>
  <style>
    body { font-family: -apple-system, system-ui, sans-serif; padding: 24px; background: #f5f5f5; }
    .card { background: white; border-radius: 12px; padding: 20px; max-width: 480px; margin: 0 auto; box-shadow: 0 2px 8px rgba(0,0,0,0.08); }
    h1 { font-size: 22px; margin-top: 0; }
    ul { padding-left: 20px; }
    .btn { display: block; width: 100%; padding: 14px; margin: 12px 0; background: #1565c0; color: white; border: none; border-radius: 10px; font-size: 16px; font-weight: 600; cursor: pointer; }
    .btn:active { background: #0d47a1; }
    .note { font-size: 13px; color: #666; margin-top: 8px; }
  </style>
</head>
<body>
  <div class="card">
    <h1>QuickSend</h1>
    <p>Files ready to download:</p>
    <button class="btn" onclick="downloadAll()">Download All</button>
    <p class="note">Images will be offered to save to your Photos. Other files go to Downloads/Files.</p>
    <ul>$items</ul>
  </div>
  <script>
    const token = "$token";
    const files = [$fileListJson];
    async function downloadAll() {
      for (const encoded of files) {
        const name = decodeURIComponent(encoded);
        const a = document.createElement('a');
        a.href = '/share/' + token + '/' + encoded;
        a.download = name;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        await new Promise(r => setTimeout(r, 400));
      }
    }
  </script>
</body>
</html>
''';
  }

  Future<String?> createShareLink(List<Map<String, String>> files) async {
    if (files.isEmpty) return null;
    try {
      final token = DateTime.now().millisecondsSinceEpoch.toString();
      _shareLinks[token] = files;

      final interfaces = await NetworkInterface.list();
      String? ip;
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            ip = addr.address;
            break;
          }
        }
        if (ip != null) break;
      }

      if (ip == null) return null;
      return 'http://$ip:$defaultPort/share/$token';
    } catch (e) {
      print('Failed to create share link: $e');
      return null;
    }
  }

  Future<void> _startBluetoothReceiver() async {
    try {
      if (await FlutterBluePlus.isSupported == false) {
        print('Bluetooth not supported');
        return;
      }
      print('Bluetooth receiver ready.');
    } catch (e) {
      print('Bluetooth receiver error: $e');
    }
  }

  Future<void> handleBleWrite(List<int> data, String fromDevice) async {
    if (data.isEmpty) return;

    final text = String.fromCharCodes(data);

    if (text.trim() == 'EOF' || text.contains('EOF')) {
      await finalizeBleReceive();
      return;
    }

    if (!_bleFilenameReceived && text.startsWith('FILENAME:')) {
      final newline = text.indexOf('\n');
      if (newline != -1) {
        _currentBleFileName = text.substring(9, newline).trim();
        _bleFilenameReceived = true;
        final remaining = data.sublist(newline + 1);
        if (remaining.isNotEmpty) {
          _bleBuffer.addAll(remaining);
        }
      }
    } else if (_bleFilenameReceived) {
      _bleBuffer.addAll(data);
    }

    if (_currentBleFileName != null) {
      final transfer = FileTransfer(
        id: 'ble_${DateTime.now().millisecondsSinceEpoch}',
        fileName: _currentBleFileName!,
        fileSize: _bleBuffer.length,
        peer: NearbyDevice(
          id: fromDevice,
          name: fromDevice,
          address: fromDevice,
          port: 0,
          platform: 'Bluetooth',
        ),
        isOutgoing: false,
        status: TransferStatus.inProgress,
        progress: 0.5,
      );
      _incomingController.add(transfer);
    }
  }

  Future<void> finalizeBleReceive() async {
    if (_bleBuffer.isEmpty || _currentBleFileName == null) {
      _resetBleState();
      return;
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      final safeName = _currentBleFileName!.replaceAll(RegExp(r'[/\\]'), '_');
      final file = File('${dir.path}/$safeName');
      await file.writeAsBytes(_bleBuffer);

      final transfer = FileTransfer(
        id: 'ble_final_${DateTime.now().millisecondsSinceEpoch}',
        fileName: safeName,
        fileSize: _bleBuffer.length,
        peer: NearbyDevice(
          id: 'ble',
          name: 'Bluetooth Device',
          address: '',
          port: 0,
          platform: 'Bluetooth',
        ),
        isOutgoing: false,
        status: TransferStatus.completed,
        progress: 1.0,
      );
      receivedFiles.add(transfer);
      _incomingController.add(transfer);
    } catch (e) {
      print('Failed to save BLE file: $e');
    } finally {
      _resetBleState();
    }
  }

  void _resetBleState() {
    _bleBuffer.clear();
    _currentBleFileName = null;
    _bleFilenameReceived = false;
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

  Future<FileTransfer> sendFile({
    required NearbyDevice peer,
    required String filePath,
    required String fileName,
    void Function(double)? onProgress,
  }) async {
    if (peer.port == 0 && peer.platform.toLowerCase().contains('bluetooth')) {
      return _sendFileOverBluetooth(
        peer: peer,
        filePath: filePath,
        fileName: fileName,
        onProgress: onProgress,
      );
    }

    return _sendFileOverHttp(
      peer: peer,
      filePath: filePath,
      fileName: fileName,
      onProgress: onProgress,
    );
  }

  Future<FileTransfer> _sendFileOverHttp({
    required NearbyDevice peer,
    required String filePath,
    required String fileName,
    void Function(double)? onProgress,
  }) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final total = bytes.length;

    final transfer = FileTransfer(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fileName: fileName,
      fileSize: total,
      peer: peer,
      isOutgoing: true,
      status: TransferStatus.inProgress,
      progress: 0.0,
    );

    try {
      onProgress?.call(0.05);

      final uri = Uri.parse('http://${peer.address}:${peer.port}/upload');
      final request = http.MultipartRequest('POST', uri)
        ..headers['x-filename'] = fileName
        ..fields['filename'] = fileName;

      final progressTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        if (transfer.progress < 0.85) {
          transfer.progress += 0.05;
          onProgress?.call(transfer.progress);
        } else {
          timer.cancel();
        }
      });

      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));
      final response = await request.send();
      progressTimer.cancel();

      onProgress?.call(0.95);
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

  Future<FileTransfer> _sendFileOverBluetooth({
    required NearbyDevice peer,
    required String filePath,
    required String fileName,
    void Function(double)? onProgress,
  }) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final total = bytes.length;

    final transfer = FileTransfer(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fileName: fileName,
      fileSize: total,
      peer: peer,
      isOutgoing: true,
      status: TransferStatus.inProgress,
      progress: 0.0,
    );

    try {
      onProgress?.call(0.05);

      final device = BluetoothDevice.fromId(peer.address);
      await device.connect(timeout: const Duration(seconds: 10));
      onProgress?.call(0.15);

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

      final header = 'FILENAME:$fileName\n';
      await transferChar.write(header.codeUnits, withoutResponse: false);
      onProgress?.call(0.2);

      const chunkSize = 180;
      int sent = 0;
      for (int i = 0; i < bytes.length; i += chunkSize) {
        final end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
        final chunk = bytes.sublist(i, end);
        await transferChar.write(chunk, withoutResponse: false);
        sent += chunk.length;
        final progress = 0.2 + (0.7 * sent / total);
        transfer.progress = progress;
        onProgress?.call(progress);
      }

      await transferChar.write('EOF'.codeUnits, withoutResponse: false);
      onProgress?.call(0.95);

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
