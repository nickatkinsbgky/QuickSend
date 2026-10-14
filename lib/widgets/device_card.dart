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
    if (p.contains('android')) return Colors.green.shade600;
    if (p.contains('ios') || p.contains('iphone')) return Colors.blueGrey.shade700;
    if (p.contains('windows')) return const Color(0xFF1565C0);
    if (p.contains('bluetooth')) return Colors.blue.shade700;
    return Colors.blueGrey;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Card(
        elevation: 3,
        shadowColor: const Color(0xFF1565C0).withOpacity(0.2),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: _platformColor().withOpacity(0.15),
                  radius: 22,
                  child: Icon(_platformIcon(), color: _platformColor(), size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${device.platform} • ${device.address}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
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
