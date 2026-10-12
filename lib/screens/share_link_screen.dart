import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ShareLinkScreen extends StatelessWidget {
  final String url;
  final List<String> fileNames;

  const ShareLinkScreen({
    super.key,
    required this.url,
    required this.fileNames,
  });

  @override
  Widget build(BuildContext context) {
    final count = fileNames.length;
    final title = count == 1 ? 'Share "${fileNames.first}"' : 'Share $count files';

    return Scaffold(
      appBar: AppBar(title: const Text('Share Link')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Anyone on the same Wi-Fi can open this link in a browser to download the file${count > 1 ? 's' : ''}.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
              textAlign: TextAlign.center,
            ),
            if (count > 1) ...[
              const SizedBox(height: 16),
              ...fileNames.map((name) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(name, style: const TextStyle(fontSize: 13)),
                  )),
            ],
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: QrImageView(
                data: url,
                version: QrVersions.auto,
                size: 220,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: SelectableText(
                url,
                style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: url));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Link copied to clipboard'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy Link'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
