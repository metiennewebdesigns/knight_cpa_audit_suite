import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/evidence_ledger.dart';

class EvidenceLedgerCard extends StatelessWidget {
  const EvidenceLedgerCard({
    super.key,
    required this.engagementId,
  });

  final String engagementId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            'Evidence Integrity Ledger',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Vault-stored evidence is hashed and verified.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.70),
                ),
          ),
          const SizedBox(height: 12),

          FutureBuilder<List<EvidenceVerifyResult>>(
            future: EvidenceLedger.verifyAll(engagementId),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final results = snap.data!;
              if (results.isEmpty) {
                return Text(
                  'No evidence recorded yet.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.70),
                      ),
                );
              }

              final shown = results.take(10).toList();

              return Column(
                children: [
                  for (final r in shown) ...[
                    _Row(result: r),
                    const SizedBox(height: 10),
                  ],
                ],
              );
            },
          ),
        ]),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.result});
  final EvidenceVerifyResult result;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final e = result.entry;

    final bool ok = result.exists && result.hashMatches;
    final bool missing = !result.exists;
    final bool mismatch = result.exists && !result.hashMatches;

    IconData icon = Icons.verified_outlined;
    Color bg = cs.secondaryContainer;
    Color border = cs.secondary.withValues(alpha: 0.35);
    String badge = 'Verified';

    if (missing) {
      icon = Icons.help_outline;
      bg = cs.surfaceContainerHighest;
      border = cs.onSurface.withValues(alpha: 0.12);
      badge = 'Missing';
    } else if (mismatch) {
      icon = Icons.warning_amber_outlined;
      bg = cs.errorContainer;
      border = cs.error.withValues(alpha: 0.40);
      badge = 'Mismatch';
    }

    return Material(
      color: cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: border),
              ),
              child: Icon(icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  '${e.logicalKey} v${e.version}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  badge,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: (ok ? cs.secondary : (mismatch ? cs.error : cs.onSurface))
                            .withValues(alpha: 0.80),
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'SHA-256: ${e.sha256.substring(0, 12)}…',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: cs.onSurface.withValues(alpha: 0.70),
                      ),
                ),
              ]),
            ),
            IconButton(
              tooltip: 'Copy hash',
              icon: const Icon(Icons.copy),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: e.sha256));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Hash copied')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}