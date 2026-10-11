enum TransferStatus { pending, inProgress, completed, failed, rejected }

class FileTransfer {
  final String id;
  final String fileName;
  final int fileSize;
  final NearbyDevice peer;
  final bool isOutgoing;
  TransferStatus status;
  double progress; // 0.0 to 1.0

  FileTransfer({
    required this.id,
    required this.fileName,
    required this.fileSize,
    required this.peer,
    required this.isOutgoing,
    this.status = TransferStatus.pending,
    this.progress = 0.0,
  });
}
