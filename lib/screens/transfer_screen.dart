import 'package:flutter/material.dart';
import '../models/device.dart';
import '../models/transfer.dart';

class TransferScreen extends StatelessWidget {
  final NearbyDevice device;

  const TransferScreen({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Send to ${device.name}')),
      body: const Center(
        child: Text('File picker and transfer progress will go here'),
      ),
    );
  }
}
