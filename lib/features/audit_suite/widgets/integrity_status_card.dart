import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/integrity_quick_check.dart';

class IntegrityStatusCard extends StatefulWidget {
  const IntegrityStatusCard({
    super.key,
    required this.engagementId,
    this.onTapOpenLedger,
    this.onExportCertificate,
  });

  final String engagementId;

  /// Scroll to ledger, open ledger, etc.
  final VoidCallback? onTapOpenLedger;

  /// Hook to export Integrity Certificate from the Engagement Detail screen.
  final VoidCallback? onExportCertificate;

  @override
  State<IntegrityStatusCard> createState() => _IntegrityStatusCardState();
}

class _IntegrityStatusCardState extends State<IntegrityStatusCard> {
  late Future<IntegrityQuickCheckResult> _future;

  @override
  void initState() {
    super.initState();
    _future = IntegrityQuickCheck.run(
      engagementId: widget.engagementId,
      maxEntriesToCheck: 20,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _future = IntegrityQuickCheck.run(
        engagementId: widget.engagementId,
        maxEntriesToCheck: 20,
      );
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return FutureBuilder<IntegrityQuickCheckResult>(
      future: _future,
      builder: (context, snap) {
        final loading = snap.connectionState != ConnectionState.done;
        final res = snap.data;

        // Web / unsupported
        if (!loading && (res?.isSupported == false)) {
          return Card(
            color: cs.surfaceVariant,
            child: const ListTile(
              leading: Icon(Icons.public),
              title: Text('Evidence Integrity'),
              subtitle: Text('Integrity check is disabled on web demo.'),
            ),
          );
        }

        final totalChecked = res?.totalChecked ?? 0;
        final issues = res?.issues ?? 0;

        final hasIssues = issues > 0;
        final bg = hasIssues ? cs.errorContainer : cs.secondaryContainer;
        final border = hasIssues ? cs.error.withValues(alpha: 0.35) : cs.secondary.withValues(alpha: 0.35);

        return Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
                      ),
                      child: const Icon(Icons.verified_outlined),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Evidence Integrity',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.2,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            loading
                                ? 'Checking last uploads…'
                                : (totalChecked == 0 ? 'No evidence recorded yet.' : 'Checked last $totalChecked entries.'),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: cs.onSurface.withValues(alpha: 0.70),
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _Pill(
                      text: loading ? '…' : (hasIssues ? 'Issues: $issues' : 'OK'),
                      bg: bg,
                      border: border,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (!loading) ...[
                  Text(
                    hasIssues
                        ? 'One or more evidence files are missing or fail hash verification. Open the ledger to review.'
                        : 'No issues detected in the last checked evidence entries.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.70),
                        ),
                  ),
                  const SizedBox(height: 12),
                ],

                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: loading ? null : _refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Re-check'),
                    ),
                    OutlinedButton.icon(
                      onPressed: widget.onTapOpenLedger,
                      icon: const Icon(Icons.list_alt_outlined),
                      label: const Text('Open Ledger'),
                    ),
                    FilledButton.icon(
                      onPressed: (kIsWeb || widget.onExportCertificate == null) ? null : widget.onExportCertificate,
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('Export Certificate'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.bg, required this.border});
  final String text;
  final Color bg;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: bg,
        border: Border.all(color: border),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}