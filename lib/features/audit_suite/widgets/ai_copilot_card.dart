import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/ai_copilot_local.dart';

class AiCopilotCard extends StatefulWidget {
  const AiCopilotCard({
    super.key,
    required this.onSummarize,
    required this.onNextActions,
    required this.onDraftPbcEmail,
    required this.onExplainPriority,
  });

  final AiCopilotAnswer Function() onSummarize;
  final AiCopilotAnswer Function() onNextActions;
  final AiCopilotAnswer Function() onDraftPbcEmail;
  final AiCopilotAnswer Function() onExplainPriority;

  @override
  State<AiCopilotCard> createState() => _AiCopilotCardState();
}

class _AiCopilotCardState extends State<AiCopilotCard> {
  AiCopilotAnswer? _ans;

  void _set(AiCopilotAnswer a) => setState(() => _ans = a);

  Future<void> _copy() async {
    if (_ans == null) return;
    await Clipboard.setData(ClipboardData(text: _ans!.body));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied ✅')));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ask AI (Local)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Offline assistant using your current engagement signals (no cloud keys).',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withOpacity(0.70),
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: () => _set(widget.onSummarize()),
                  icon: const Icon(Icons.summarize_outlined),
                  label: const Text('Summarize'),
                ),
                FilledButton.icon(
                  onPressed: () => _set(widget.onNextActions()),
                  icon: const Icon(Icons.playlist_add_check_outlined),
                  label: const Text('Next actions'),
                ),
                FilledButton.icon(
                  onPressed: () => _set(widget.onDraftPbcEmail()),
                  icon: const Icon(Icons.email_outlined),
                  label: const Text('Draft PBC email'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _set(widget.onExplainPriority()),
                  icon: const Icon(Icons.help_outline),
                  label: const Text('Explain priority'),
                ),
              ],
            ),
            if (_ans != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cs.onSurface.withOpacity(0.10)),
                ),
                child: SelectableText(
                  _ans!.body,
                  style: const TextStyle(height: 1.25),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _copy,
                  icon: const Icon(Icons.copy_all_outlined),
                  label: const Text('Copy'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}