import 'dart:io';
import 'package:flutter/material.dart';

class FileThumbnail extends StatelessWidget {
  final String? filePath;
  final String fileName;
  final double size;

  const FileThumbnail({
    super.key,
    this.filePath,
    required this.fileName,
    this.size = 64,
  });

  bool get _isImage {
    final lower = fileName.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.bmp');
  }

  @override
  Widget build(BuildContext context) {
    if (_isImage && filePath != null && File(filePath!).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(filePath!),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _icon,
        ),
      );
    }
    return _icon;
  }

  Widget get _icon => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          _isImage ? Icons.image : Icons.insert_drive_file,
          size: size * 0.5,
          color: Colors.grey.shade600,
        ),
      );
}
