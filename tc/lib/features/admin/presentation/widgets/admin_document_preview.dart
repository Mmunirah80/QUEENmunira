import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Storage bucket for cook verification files (see [DocumentsScreen]).
const String kAdminCookDocumentsBucket = 'documents';

/// Returns an https URL for viewing: full URL passthrough, or signed URL for storage paths.
Future<String?> resolveCookDocumentFileUrl(String? raw) async {
  if (raw == null) return null;
  final t = raw.trim();
  if (t.isEmpty) return null;
  if (t.startsWith('http://') || t.startsWith('https://')) {
    return t;
  }
  try {
    return await Supabase.instance.client.storage.from(kAdminCookDocumentsBucket).createSignedUrl(t, 3600);
  } catch (_) {
    return null;
  }
}

bool looksLikePdfUrl(String url) {
  final u = url.toLowerCase();
  return u.contains('.pdf') || u.contains('content-type=application%2Fpdf');
}

Future<void> openCookDocumentPreview(BuildContext context, String? fileUrlRaw) async {
  final resolved = await resolveCookDocumentFileUrl(fileUrlRaw);
  if (!context.mounted) return;
  if (resolved == null || resolved.isEmpty) {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('File unavailable'),
        content: const Text(
          'We could not resolve a viewable link for this document. It may be missing in storage or the path is invalid.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
    return;
  }
  if (looksLikePdfUrl(resolved)) {
    final uri = Uri.tryParse(resolved);
    if (uri == null) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('File unavailable'),
          content: const Text('The document link could not be opened.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ],
        ),
      );
      return;
    }
    final ok = await launchUrl(
      uri,
      mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
      webOnlyWindowName: kIsWeb ? '_blank' : null,
    );
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open PDF')),
      );
    }
    return;
  }

  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (ctx) => _AdminImagePreviewScreen(imageUrl: resolved),
    ),
  );
}

class _AdminImagePreviewScreen extends StatelessWidget {
  const _AdminImagePreviewScreen({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Padding(
                padding: EdgeInsets.all(48),
                child: CircularProgressIndicator(color: Colors.white),
              );
            },
            errorBuilder: (_, __, ___) => const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Could not load image',
                style: TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
