import 'package:flutter/material.dart';
import '../models/device.dart';

class DeviceCard extends StatelessWidget {
  final NearbyDevice device;
  final VoidCallback? onTap;

  const DeviceCard({super.key, required this.device, this.onTap});

  IconData _platformIcon() {
    final p = device.platform.toLowerCase();
    if (p.contains('android')) return Icons.android;
    if (p.contains('ios') || p.contains('iphone')) return Icons.phone_iphone;
    if (p.contains('windows')) return Icons.computer;
    if (p.contains('mac')) return Icons.laptop_mac;
    if (p.contains('bluetooth')) return Icons.bluetooth;
    return Icons.devices;
  }

  Color _platformColor() {
    final p = device.platform.toLowerCase();
    if (p.contains('android')) return Colors.green;
    if (p.contains('ios') || p.contains('iphone')) return Colors.grey.shade700;
    if (p.contains('windows')) return Colors.blue;
    if (p.contains('bluetooth')) return Colors.blue.shade700;
    return Colors.blueGrey;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: _platformColor().withOpacity(0.12),
                  child: Icon(_platformIcon(), color: _platformColor()),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${device.platform} • ${device.address}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
