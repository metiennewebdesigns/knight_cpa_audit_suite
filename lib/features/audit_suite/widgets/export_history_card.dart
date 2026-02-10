import 'package:flutter/material.dart';

import '../../../core/storage/local_store.dart';
import '../services/export_history.dart';

class ExportHistoryCard extends StatelessWidget {
  const ExportHistoryCard({
    super.key,
    required this.store,
    required this.engagementId,
  });

  final LocalStore store;
  final String engagementId;

  String _prettyWhenIso(String iso) {
    final s = iso.trim();
    if (s.isEmpty) return '—';
    final dt = DateTime.tryParse(s);
    if (dt == null) return s;
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Widget _pill(BuildContext context, {required String text, required Color bg, required Color border}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: bg,
        border: Border.all(color: border),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return FutureBuilder<ExportHistoryVm>(
      future: ExportHistoryReader.load(store, engagementId),
      builder: (context, snap) {
        final vm = snap.data ?? ExportHistoryVm.empty;

        return Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Export History',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Counts + last export timestamps (desktop only).',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.70),
                      ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _pill(
                      context,
                      text: 'Deliverable Pack: ${vm.deliverablePackCount} • ${_prettyWhenIso(vm.deliverableLastIso)}',
                      bg: cs.surfaceVariant,
                      border: cs.onSurface.withValues(alpha: 0.10),
                    ),
                    _pill(
                      context,
                      text: 'Audit Packet: ${vm.auditPacketCount} • ${_prettyWhenIso(vm.packetLastIso)}',
                      bg: cs.surfaceVariant,
                      border: cs.onSurface.withValues(alpha: 0.10),
                    ),
                    _pill(
                      context,
                      text: 'Integrity Cert: ${vm.integrityCertCount} • ${_prettyWhenIso(vm.certLastIso)}',
                      bg: cs.surfaceVariant,
                      border: cs.onSurface.withValues(alpha: 0.10),
                    ),
                    _pill(
                      context,
                      text: 'Portal Audit: ${vm.portalAuditCount} • ${_prettyWhenIso(vm.portalAuditLastIso)}',
                      bg: cs.surfaceVariant,
                      border: cs.onSurface.withValues(alpha: 0.10),
                    ),
                    _pill(
                      context,
                      text: 'Letters: ${vm.lettersCount} • ${_prettyWhenIso(vm.lettersLastIso)}',
                      bg: cs.surfaceVariant,
                      border: cs.onSurface.withValues(alpha: 0.10),
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