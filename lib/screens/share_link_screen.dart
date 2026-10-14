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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
            ),
          ),
        ),
        title: const Text('Share Link'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 120, 24, 32),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Anyone on the same Wi-Fi can open this link in a browser to download the file${count > 1 ? 's' : ''}.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
              textAlign: TextAlign.center,
            ),
            if (count > 1) ...[
              const SizedBox(height: 16),
              ...fileNames.map((name) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  )),
            ],
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1565C0).withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
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
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: SelectableText(
                url,
                style: const TextStyle(fontSize: 14, fontFamily: 'monospace', fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: url));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Link copied to clipboard'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: Theme.of(context).colorScheme.primary,
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
