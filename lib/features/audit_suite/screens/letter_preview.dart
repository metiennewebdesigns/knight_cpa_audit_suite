import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/storage/local_store.dart';
import '../services/letter_exporter.dart';


class LetterPreviewScreen extends StatefulWidget {
  const LetterPreviewScreen({
    super.key,
    required this.store,
    required this.themeMode,
    required this.engagementId,
    required this.type,
  });

  final LocalStore store;
  final ValueNotifier<ThemeMode> themeMode;
  final String engagementId;

  /// "engagement" | "pbc" | "mrl"
  final String type;

  @override
  State<LetterPreviewScreen> createState() => _LetterPreviewScreenState();
}

class _LetterPreviewScreenState extends State<LetterPreviewScreen> {
  bool _busy = false;
  bool _exported = false;

  String get _title {
    switch (widget.type) {
      case 'engagement':
        return 'Engagement Letter';
      case 'pbc':
        return 'PBC Request Letter';
      case 'mrl':
        return 'Management Rep Letter';
      default:
        return 'Letter';
    }
  }

  Future<void> _export() async {
    if (_busy) return;

    setState(() => _busy = true);
    try {
      final res = await LetterExporter.exportPdf(
        store: widget.store,
        engagementId: widget.engagementId,
        type: widget.type,
      );

      _exported = true;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved: ${res.savedFileName}'),
          duration: const Duration(seconds: 2),
        ),
      );

      // Optional auto-open on desktop. Don’t spam snackbars—only show if it actually opened.
      if (res.didOpenFile) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opened PDF ✅'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _back() {
    // Return whether we exported, so LettersScreen can bubble that up
    context.pop(_exported);
  }

  @override
  Widget build(BuildContext context) {
    final preview = LetterExporter.buildLetterTextPreview(
      engagementId: widget.engagementId,
      type: widget.type,
    );

    return WillPopScope(
      onWillPop: () async {
        _back();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_title),
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back),
            onPressed: _busy ? null : _back,
          ),
          actions: [
            IconButton(
              tooltip: 'Export PDF',
              onPressed: _busy ? null : _export,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Locked template (Phase 1). Export only.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  preview,
                  style: const TextStyle(height: 1.35),
                ),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _busy ? null : _export,
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: Text(_busy ? 'Exporting…' : 'Export PDF to Documents'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : _back,
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }
}