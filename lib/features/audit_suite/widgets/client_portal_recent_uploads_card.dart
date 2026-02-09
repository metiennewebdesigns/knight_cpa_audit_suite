import 'package:flutter/material.dart';

import '../services/evidence_ledger.dart';

class ClientPortalRecentUploadsCard extends StatefulWidget {
  const ClientPortalRecentUploadsCard({
    super.key,
    required this.engagementId,
    this.limit = 10,
  });

  final String engagementId;
  final int limit;

  @override
  State<ClientPortalRecentUploadsCard> createState() => _ClientPortalRecentUploadsCardState();
}

class _ClientPortalRecentUploadsCardState extends State<ClientPortalRecentUploadsCard> {
  late Future<List<EvidenceLedgerEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = EvidenceLedger.readAll(widget.engagementId);
  }

  void refresh() {
    setState(() {
      _future = EvidenceLedger.readAll(widget.engagementId);
    });
  }

  String _prettyWhen(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso.isEmpty ? '—' : iso;
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: FutureBuilder<List<EvidenceLedgerEntry>>(
          future: _future,
          builder: (context, snap) {
            final list = (snap.data ?? const <EvidenceLedgerEntry>[]).reversed.toList();
            final recent = list.take(widget.limit).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.cloud_done_outlined),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Recent Uploads',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.2,
                            ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh',
                      onPressed: refresh,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Uploads recorded to the Evidence Integrity Ledger.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.70),
                      ),
                ),
                const SizedBox(height: 12),

                if (snap.connectionState != ConnectionState.done)
                  const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
                else if (recent.isEmpty)
                  Text(
                    'No uploads yet.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.70),
                        ),
                  )
                else
                  ...recent.map((e) {
                    final shaShort = e.sha256.length >= 12 ? '${e.sha256.substring(0, 12)}…' : e.sha256;
                    final when = _prettyWhen(e.ts);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.insert_drive_file_outlined),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    e.fileName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w900,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$when • SHA $shaShort',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: cs.onSurface.withValues(alpha: 0.70),
                                          fontFamily: 'monospace',
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }
}