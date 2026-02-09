import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/letter_exporter.dart';
import '../../../core/storage/local_store.dart';

class LetterPreviewScreen extends StatefulWidget {
  const LetterPreviewScreen({
    super.key,
    required this.store,
    required this.engagementId,
    this.initialType = 'engagement',
  });

  final LocalStore store;
  final String engagementId;
  final String initialType;

  @override
  State<LetterPreviewScreen> createState() => _LetterPreviewScreenState();
}

class _LetterPreviewScreenState extends State<LetterPreviewScreen> {
  late String _type;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
  }

  String get _title {
    switch (_type) {
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

  String get _previewText => LetterExporter.buildLetterTextPreview(
        engagementId: widget.engagementId,
        type: _type,
      );

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: _previewText));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }

  Future<void> _exportPdf() async {
    setState(() => _exporting = true);
    try {
      final res = await LetterExporter.exportPdf(
        store: widget.store,
        engagementId: widget.engagementId,
        type: _type,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved ${res.savedFileName}'),
          action: SnackBarAction(
            label: 'Copy path',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: res.savedPath));
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          IconButton(
            tooltip: 'Copy',
            onPressed: _copyToClipboard,
            icon: const Icon(Icons.copy),
          ),
        ],
      ),
      body: Column(
        children: [
          // Controls
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _type,
                    decoration: const InputDecoration(
                      labelText: 'Letter type',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'engagement',
                        child: Text('Engagement Letter'),
                      ),
                      DropdownMenuItem(
                        value: 'pbc',
                        child: Text('PBC Request Letter'),
                      ),
                      DropdownMenuItem(
                        value: 'mrl',
                        child: Text('Management Rep Letter'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _type = v);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _exporting ? null : _exportPdf,
                  icon: _exporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.picture_as_pdf),
                  label: Text(_exporting ? 'Exporting…' : 'Export PDF'),
                ),
              ],
            ),
          ),

          // Preview
          Expanded(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  _previewText,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}