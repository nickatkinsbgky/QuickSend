import '../models/device.dart';
import '../models/transfer.dart';

class TransferService {
  Future<FileTransfer> sendFile({
    required NearbyDevice peer,
    required String filePath,
    required String fileName,
  }) async {
    // TODO: Implement HTTP POST or chunked transfer to peer's IP:port
    // Return a FileTransfer object with progress updates via stream
    throw UnimplementedError('Send file not yet implemented');
  }

  Stream<FileTransfer> receiveTransfers() {
    // TODO: Start a local HTTP server to accept incoming files
    // Emit FileTransfer events for incoming requests
    throw UnimplementedError('Receive not yet implemented');
  }
}
