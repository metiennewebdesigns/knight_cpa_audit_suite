import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/storage/local_store.dart';

import '../data/models/repositories/clients_repository.dart';
import '../data/models/repositories/engagements_repository.dart';
import '../data/models/repositories/workpapers_repository.dart';

import '../services/access_control.dart';
import '../services/deliverable_pack_exporter.dart';
import '../services/evidence_integrity_certificate_exporter.dart';
import '../services/evidence_ledger.dart';

enum GlobalSearchItemType { client, engagement, workpaper, pbcItem, evidence }

class GlobalSearchItem {
  final GlobalSearchItemType type;
  final String title;
  final String subtitle;
  final IconData icon;

  // Routing targets
  final String? routeName;
  final Map<String, String>? pathParameters;
  final String? fallbackPath;

  // For quick actions
  final String? engagementId;

  const GlobalSearchItem({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.routeName,
    this.pathParameters,
    this.fallbackPath,
    this.engagementId,
  });
}

class GlobalSearchSheet {
  // ✅ Cache (fast open)
  static List<GlobalSearchItem>? _cache;
  static DateTime? _cacheAt;

  static const Duration cacheTtl = Duration(minutes: 5);

  static Future<void> open(
    BuildContext context, {
    required LocalStore store,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => _GlobalSearchSheetBody(store: store),
    );
  }

  static bool get _cacheValid {
    final at = _cacheAt;
    if (_cache == null || at == null) return false;
    return DateTime.now().difference(at) <= cacheTtl;
  }

  static Future<List<GlobalSearchItem>> getIndex(LocalStore store, {bool force = false}) async {
    if (!force && _cacheValid) return _cache!;
    final items = await _buildIndex(store);
    _cache = items;
    _cacheAt = DateTime.now();
    return items;
  }

  static void clearCache() {
    _cache = null;
    _cacheAt = null;
  }
}

class _GlobalSearchSheetBody extends StatefulWidget {
  const _GlobalSearchSheetBody({required this.store});
  final LocalStore store;

  @override
  State<_GlobalSearchSheetBody> createState() => _GlobalSearchSheetBodyState();
}

class _GlobalSearchSheetBodyState extends State<_GlobalSearchSheetBody> {
  final _queryCtrl = TextEditingController();
  final _focusNode = FocusNode();

  bool _loading = true;
  List<GlobalSearchItem> _all = const [];
  List<GlobalSearchItem> _filtered = const [];

  AppRole _role = AppRole.owner;

  @override
  void initState() {
    super.initState();
    _initRole();
    _loadIndex(force: false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });

    _queryCtrl.addListener(_applyFilter);
  }

  Future<void> _initRole() async {
    final r = await AccessControl.getRole();
    if (!mounted) return;
    setState(() => _role = r);
  }

  @override
  void dispose() {
    _queryCtrl.removeListener(_applyFilter);
    _queryCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadIndex({required bool force}) async {
    setState(() => _loading = true);
    try {
      final items = await GlobalSearchSheet.getIndex(widget.store, force: force);
      setState(() {
        _all = items;
        _filtered = items;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<String> _queryWords() {
    final q = _queryCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return q.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
  }

  void _applyFilter() {
    final words = _queryWords();
    if (words.isEmpty) {
      setState(() => _filtered = _all);
      return;
    }

    bool match(GlobalSearchItem it) {
      final hay = '${it.title} ${it.subtitle}'.toLowerCase();
      for (final w in words) {
        if (!hay.contains(w)) return false;
      }
      return true;
    }

    setState(() {
      _filtered = _all.where(match).take(120).toList();
    });
  }

  void _openItem(GlobalSearchItem it) {
    Navigator.of(context).pop();

    if (it.routeName != null && it.pathParameters != null) {
      context.pushNamed(it.routeName!, pathParameters: it.pathParameters!);
      return;
    }
    if (it.fallbackPath != null && it.fallbackPath!.isNotEmpty) {
      context.push(it.fallbackPath!);
      return;
    }
  }

  Future<void> _quickActions(GlobalSearchItem it) async {
    // Only engagements get fast actions
    if (it.engagementId == null || it.engagementId!.isEmpty) {
      _openItem(it);
      return;
    }

    final eid = it.engagementId!;
    final canQuickExports = AccessControl.canUseQuickExports(_role);

    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.work_outline),
              title: const Text('Open Engagement'),
              onTap: () => Navigator.of(ctx).pop('open_eng'),
            ),
            ListTile(
              leading: const Icon(Icons.open_in_new_outlined),
              title: const Text('Open Client Portal'),
              onTap: () => Navigator.of(ctx).pop('open_portal'),
            ),
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: const Text('Export Deliverable Pack'),
              enabled: canQuickExports,
              onTap: canQuickExports ? () => Navigator.of(ctx).pop('export_pack') : null,
            ),
            ListTile(
              leading: const Icon(Icons.verified_outlined),
              title: const Text('Export Integrity Certificate'),
              enabled: canQuickExports,
              onTap: canQuickExports ? () => Navigator.of(ctx).pop('export_cert') : null,
            ),
          ],
        ),
      ),
    );

    if (choice == null) return;

    // Close search sheet before navigating/exporting
    Navigator.of(context).pop();

    Future.microtask(() async {
      try {
        switch (choice) {
          case 'open_eng':
            context.pushNamed('engagementDetail', pathParameters: {'id': eid});
            break;

          case 'open_portal':
            context.pushNamed('clientPortal', pathParameters: {'id': eid});
            break;

          case 'export_pack':
            if (!AccessControl.canUseQuickExports(_role)) {
              _toast('Not allowed for role: ${AccessControl.roleLabel(_role)}');
              return;
            }
            final res = await DeliverablePackExporter.exportPdf(store: widget.store, engagementId: eid);
            _toast('Deliverable Pack exported ✅ (${res.savedFileName})');
            break;

          case 'export_cert':
            if (!AccessControl.canUseQuickExports(_role)) {
              _toast('Not allowed for role: ${AccessControl.roleLabel(_role)}');
              return;
            }
            final engRepo = EngagementsRepository(widget.store);
            final clientsRepo = ClientsRepository(widget.store);

            final eng = await engRepo.getById(eid);
            if (eng == null) throw StateError('Engagement not found');

            final client = await clientsRepo.getById(eng.clientId);
            final clientName = (client?.name ?? eng.clientId).toString();

            final res = await EvidenceIntegrityCertificateExporter.exportPdf(
              engagementId: eid,
              engagementTitle: eng.title,
              clientName: clientName,
              engagementStatus: eng.status,
            );

            _toast('Certificate exported ✅ (${res.savedFileName})');
            break;
        }
      } catch (e) {
        _toast('Action failed: $e');
      }
    });
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Map<String, List<GlobalSearchItem>> _grouped(List<GlobalSearchItem> list) {
    String label(GlobalSearchItemType t) {
      switch (t) {
        case GlobalSearchItemType.client:
          return 'Clients';
        case GlobalSearchItemType.engagement:
          return 'Engagements';
        case GlobalSearchItemType.pbcItem:
          return 'PBC Items';
        case GlobalSearchItemType.evidence:
          return 'Evidence Uploads';
        case GlobalSearchItemType.workpaper:
          return 'Workpapers';
      }
    }

    final map = <String, List<GlobalSearchItem>>{};
    for (final it in list) {
      final k = label(it.type);
      (map[k] ??= <GlobalSearchItem>[]).add(it);
    }
    return map;
  }

  // ✅ Highlight matcher (simple + fast)
  InlineSpan _highlightText(String text, List<String> words, TextStyle base, TextStyle hit) {
    if (words.isEmpty) return TextSpan(text: text, style: base);

    final lower = text.toLowerCase();
    final ranges = <_Range>[];

    for (final w in words) {
      int start = 0;
      while (true) {
        final idx = lower.indexOf(w, start);
        if (idx == -1) break;
        ranges.add(_Range(idx, idx + w.length));
        start = idx + w.length;
      }
    }

    if (ranges.isEmpty) return TextSpan(text: text, style: base);

    // merge overlaps
    ranges.sort((a, b) => a.start.compareTo(b.start));
    final merged = <_Range>[];
    for (final r in ranges) {
      if (merged.isEmpty) {
        merged.add(r);
      } else {
        final last = merged.last;
        if (r.start <= last.end) {
          merged[merged.length - 1] = _Range(last.start, (r.end > last.end) ? r.end : last.end);
        } else {
          merged.add(r);
        }
      }
    }

    final spans = <InlineSpan>[];
    int cur = 0;
    for (final r in merged) {
      if (r.start > cur) {
        spans.add(TextSpan(text: text.substring(cur, r.start), style: base));
      }
      spans.add(TextSpan(text: text.substring(r.start, r.end), style: hit));
      cur = r.end;
    }
    if (cur < text.length) {
      spans.add(TextSpan(text: text.substring(cur), style: base));
    }

    return TextSpan(children: spans);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final grouped = _grouped(_filtered);
    final order = const ['Engagements', 'Clients', 'PBC Items', 'Evidence Uploads', 'Workpapers'];
    final words = _queryWords();

    final baseTitle = Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w900,
        ) ??
        const TextStyle(fontWeight: FontWeight.w900);

    final baseSub = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: cs.onSurface.withValues(alpha: 0.70),
        ) ??
        TextStyle(color: cs.onSurface.withValues(alpha: 0.70));

    final hitStyle = baseTitle.copyWith(
      backgroundColor: cs.tertiaryContainer.withValues(alpha: 0.6),
    );

    final hitSubStyle = baseSub.copyWith(
      backgroundColor: cs.tertiaryContainer.withValues(alpha: 0.6),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: 620,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  const Icon(Icons.search),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _queryCtrl,
                      focusNode: _focusNode,
                      decoration: const InputDecoration(
                        hintText: 'Search clients, engagements, PBC items, uploads…',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    tooltip: 'Refresh index',
                    onPressed: _loading ? null : () => _loadIndex(force: true),
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_filtered.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    'No results',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.70),
                        ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    for (final key in order)
                      if ((grouped[key] ?? const []).isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 10, bottom: 6),
                          child: Text(
                            '$key (${grouped[key]!.length})',
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: cs.onSurface.withValues(alpha: 0.75),
                                ),
                          ),
                        ),
                        for (final it in grouped[key]!) ...[
                          Material(
                            color: cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => _openItem(it),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                                child: Row(
                                  children: [
                                    Icon(it.icon),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          RichText(
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            text: _highlightText(it.title, words, baseTitle, hitStyle),
                                          ),
                                          const SizedBox(height: 4),
                                          RichText(
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            text: _highlightText(it.subtitle, words, baseSub, hitSubStyle),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: it.type == GlobalSearchItemType.engagement ? 'Actions' : 'Open',
                                      onPressed: () => _quickActions(it),
                                      icon: Icon(
                                        it.type == GlobalSearchItemType.engagement ? Icons.more_horiz : Icons.open_in_new,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Range {
  final int start;
  final int end;
  const _Range(this.start, this.end);
}

/* ========================= Index builder ========================= */

Future<List<GlobalSearchItem>> _buildIndex(LocalStore store) async {
  final clientsRepo = ClientsRepository(store);
  final engRepo = EngagementsRepository(store);
  final wpRepo = WorkpapersRepository(store);

  final clients = await clientsRepo.getClients();
  final engagements = await engRepo.getEngagements();
  final workpapers = await wpRepo.getWorkpapers();

  final docs = await getApplicationDocumentsDirectory();
  final docsPath = docs.path;

  final clientNameById = <String, String>{
    for (final c in clients) c.id: c.name,
  };

  final items = <GlobalSearchItem>[];

  // Clients
  for (final c in clients) {
    items.add(
      GlobalSearchItem(
        type: GlobalSearchItemType.client,
        icon: Icons.apartment_outlined,
        title: c.name,
        subtitle: 'Client • ${c.id}',
        routeName: 'clientDetail',
        pathParameters: {'id': c.id},
      ),
    );
  }

  // Engagements
  for (final e in engagements) {
    final clientName = clientNameById[e.clientId] ?? e.clientId;
    items.add(
      GlobalSearchItem(
        type: GlobalSearchItemType.engagement,
        icon: Icons.work_outline,
        title: e.title,
        subtitle: 'Engagement • $clientName • ${e.status}',
        routeName: 'engagementDetail',
        pathParameters: {'id': e.id},
        engagementId: e.id,
      ),
    );
  }

  // Workpapers
  for (final w in workpapers) {
    items.add(
      GlobalSearchItem(
        type: GlobalSearchItemType.workpaper,
        icon: Icons.folder_open_outlined,
        title: w.title,
        subtitle: 'Workpaper • ${w.status} • ${w.engagementId}',
        routeName: 'workpaperDetail',
        pathParameters: {'id': w.id},
      ),
    );
  }

  // PBC items (read all engagement PBC json files)
  final pbcDir = Directory(p.join(docsPath, 'Auditron', 'PBC'));
  if (await pbcDir.exists()) {
    final files = pbcDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.json'))
        .toList();

    for (final f in files) {
      final engagementId = p.basenameWithoutExtension(f.path);
      try {
        final raw = await f.readAsString();
        if (raw.trim().isEmpty) continue;
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final list = (data['items'] as List<dynamic>? ?? const []);
        for (final it in list) {
          if (it is! Map) continue;
          final title = (it['title'] ?? it['name'] ?? 'PBC Item').toString();
          final status = (it['status'] ?? '').toString();
          items.add(
            GlobalSearchItem(
              type: GlobalSearchItemType.pbcItem,
              icon: Icons.fact_check_outlined,
              title: title,
              subtitle: 'PBC • $status • $engagementId',
              routeName: 'pbcList',
              pathParameters: {'id': engagementId},
              engagementId: engagementId,
            ),
          );
        }
      } catch (_) {}
    }
  }

  // Evidence uploads (ledger)
  for (final e in engagements) {
    try {
      final ledger = await EvidenceLedger.readAll(e.id);
      for (final entry in ledger.reversed.take(50)) {
        final shaShort = entry.sha256.isEmpty
            ? '—'
            : entry.sha256.substring(0, entry.sha256.length >= 12 ? 12 : entry.sha256.length);
        items.add(
          GlobalSearchItem(
            type: GlobalSearchItemType.evidence,
            icon: Icons.verified_outlined,
            title: entry.fileName,
            subtitle: 'Evidence • ${e.title} • SHA $shaShort…',
            routeName: 'engagementDetail',
            pathParameters: {'id': e.id},
            engagementId: e.id,
          ),
        );
      }
    } catch (_) {}
  }

  return items;
}