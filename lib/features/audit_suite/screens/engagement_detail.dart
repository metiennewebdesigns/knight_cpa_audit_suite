import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import '../../../core/storage/local_store.dart';

import '../data/models/engagement_models.dart';
import '../data/models/workpaper_models.dart';
import '../data/models/risk_assessment_models.dart';

import '../data/models/repositories/clients_repository.dart';
import '../data/models/repositories/engagements_repository.dart';
import '../data/models/repositories/workpapers_repository.dart';
import '../data/models/repositories/risk_assessments_repository.dart';
import '../data/models/repositories/discrepancies_repository.dart';

import '../services/ai_priority.dart';
import '../services/ai_priority_history.dart';
import '../services/export_history.dart';
import '../services/ai_copilot_local.dart';

import '../services/deliverable_pack_exporter.dart';
import '../services/evidence_ledger.dart';
import '../services/letter_exporter.dart';
import '../services/evidence_integrity_certificate_exporter.dart';
import '../services/client_portal_audit_exporter.dart';

import '../services/engagement_detail_fs.dart';

import '../widgets/evidence_ledger_card.dart';
import '../widgets/audit_timeline_card.dart';
import '../widgets/integrity_status_card.dart';
import '../widgets/ai_copilot_card.dart';
import '../widgets/export_history_card.dart';

class EngagementDetailScreen extends StatefulWidget {
  const EngagementDetailScreen({
    super.key,
    required this.store,
    required this.themeMode,
    required this.engagementId,
  });

  final LocalStore store;
  final ValueNotifier<ThemeMode> themeMode;
  final String engagementId;

  @override
  State<EngagementDetailScreen> createState() => _EngagementDetailScreenState();
}

class _EngagementDetailScreenState extends State<EngagementDetailScreen> {
  late final EngagementsRepository _engRepo;
  late final ClientsRepository _clientsRepo;
  late final WorkpapersRepository _wpRepo;
  late final RiskAssessmentsRepository _riskRepo;
  late final DiscrepanciesRepository _discRepo;

  late Future<_Vm> _future;
  bool _busy = false;
  bool _changed = false;

  final GlobalKey _ledgerKey = GlobalKey();

  bool get _canFile => !kIsWeb && widget.store.canUseFileSystem;
  String get _docsPath => widget.store.documentsPath ?? '';

  @override
  void initState() {
    super.initState();
    _engRepo = EngagementsRepository(widget.store);
    _clientsRepo = ClientsRepository(widget.store);
    _wpRepo = WorkpapersRepository(widget.store);
    _riskRepo = RiskAssessmentsRepository(widget.store);
    _discRepo = DiscrepanciesRepository(widget.store);

    _future = _load();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _prettyIsoShort(String iso) {
    final s = iso.trim();
    if (s.isEmpty) return '—';
    final dt = DateTime.tryParse(s);
    if (dt == null) return s;
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    return '${dt.year}-$mm-$dd $hh:$mi';
    }

  /* ======================= AI Priority (save or preview) ======================= */

  AiPriorityResult _computeAiPreview(_Vm vm) {
    if (vm.engagement.hasAiPriority) {
      return AiPriorityResult(
        label: vm.engagement.aiPriorityLabel.isEmpty ? 'Medium' : vm.engagement.aiPriorityLabel,
        score: vm.engagement.aiPriorityScore,
        reason: vm.engagement.aiPriorityReason.isEmpty ? '—' : vm.engagement.aiPriorityReason,
      );
    }

    return AiPriorityScorer.score(
      engagement: vm.engagement,
      risk: vm.risk,
      pbcOverdueCount: vm.pbcOverdueCount,
      integrityIssues: vm.integrityIssues,
      openWorkpapers: vm.openWorkpapers,
      totalWorkpapers: vm.totalWorkpapers,
      discrepancyOpenCount: vm.discrepancyOpenCount,
      discrepancyOpenTotal: vm.discrepancyOpenTotal,
    );
  }

  Future<void> _refreshAiPriority(_Vm vm) async {
    if (_busy) return;

    setState(() => _busy = true);
    try {
      final ai = AiPriorityScorer.score(
        engagement: vm.engagement,
        risk: vm.risk,
        pbcOverdueCount: vm.pbcOverdueCount,
        integrityIssues: vm.integrityIssues,
        openWorkpapers: vm.openWorkpapers,
        totalWorkpapers: vm.totalWorkpapers,
        discrepancyOpenCount: vm.discrepancyOpenCount,
        discrepancyOpenTotal: vm.discrepancyOpenTotal,
      );

      final updatedEng = vm.engagement.copyWith(
        aiPriorityLabel: ai.label,
        aiPriorityScore: ai.score,
        aiPriorityReason: ai.reason,
        aiPriorityUpdatedAt: DateTime.now().toIso8601String(),
      );

      try {
        await _engRepo.upsert(updatedEng);

        // history only if saved
        await AiPriorityHistoryStore.append(
          widget.store,
          engagementId: widget.engagementId,
          label: ai.label,
          score: ai.score,
          reason: ai.reason,
        );

        _snack('AI Priority saved ✅ (${ai.label} ${ai.score})');
        await _refresh();
      } catch (e) {
        final msg = e.toString().toLowerCase();
        if (msg.contains('permission denied') || msg.contains('client users cannot')) {
          _snack('AI Priority preview: ${ai.label} (${ai.score}) • ${ai.reason}');
        } else {
          _snack('AI Priority failed: $e');
        }
      }
    } catch (e) {
      _snack('AI Priority failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /* ======================= Meta + PIN ======================= */

  String _metaDirPath() => p.join(_docsPath, 'Auditron', 'EngagementMeta');
  String _metaFilePath() => p.join(_metaDirPath(), '${widget.engagementId}.json');

  String _genPin6() => (Random.secure().nextInt(900000) + 100000).toString();

  Future<String> _readPinOrEmpty() async {
    if (!_canFile) return '';
    try {
      final fp = _metaFilePath();
      if (!await fileExists(fp)) return '';
      final raw = await readTextFile(fp);
      if (raw.trim().isEmpty) return '';
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return (data['clientPortalPin'] ?? '').toString().trim();
    } catch (_) {
      return '';
    }
  }

  Future<String> _ensurePin() async {
    if (!_canFile) throw UnsupportedError('Not supported in web demo');

    await ensureDir(_metaDirPath());

    final fp = _metaFilePath();
    Map<String, dynamic> data = {};

    if (await fileExists(fp)) {
      final raw = await readTextFile(fp);
      if (raw.trim().isNotEmpty) data = jsonDecode(raw) as Map<String, dynamic>;
    }

    final existing = (data['clientPortalPin'] ?? '').toString().trim();
    if (existing.isNotEmpty) return existing;

    final pin = _genPin6();
    data['clientPortalPin'] = pin;
    data['clientPortalPinCreatedAt'] = DateTime.now().toIso8601String();
    await writeTextFile(fp, jsonEncode(data));

    return pin;
  }

  Future<void> _copyPortalInvite() async {
    if (!_canFile) {
      _snack('Client Portal invite is disabled on web demo.');
      return;
    }

    final pin = await _ensurePin();
    final inAppLink = '/engagements/${widget.engagementId}/client-portal?pin=$pin';
    final deepLink = 'auditron://client-portal/${widget.engagementId}?pin=$pin';

    final msg = '''
Client Portal Access

Engagement ID: ${widget.engagementId}

PIN: $pin

Open inside Auditron:
$inAppLink

Deep link:
$deepLink
''';

    await Clipboard.setData(ClipboardData(text: msg));
    _snack('Client Portal invite copied ✅');
  }

  Future<void> _regeneratePin() async {
    if (!_canFile) {
      _snack('PIN regeneration is disabled on web demo.');
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dc) => AlertDialog(
        title: const Text('Regenerate Client Portal PIN?'),
        content: const Text('This invalidates the old PIN immediately.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dc).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(dc).pop(true), child: const Text('Regenerate')),
        ],
      ),
    );
    if (ok != true) return;

    await ensureDir(_metaDirPath());

    final data = <String, dynamic>{
      'clientPortalPin': _genPin6(),
      'clientPortalPinRotatedAt': DateTime.now().toIso8601String(),
    };
    await writeTextFile(_metaFilePath(), jsonEncode(data));

    await Clipboard.setData(ClipboardData(text: 'New Client Portal PIN: ${data['clientPortalPin']}'));
    _snack('New PIN generated + copied ✅');

    await _refresh();
  }

  /* ======================= Portal activity ======================= */

  String _portalLogPath() => p.join(_docsPath, 'Auditron', 'ClientPortalLogs', '${widget.engagementId}.jsonl');

  Future<List<Map<String, dynamic>>> _readPortalLog({int limit = 10}) async {
    if (!_canFile) return const <Map<String, dynamic>>[];
    try {
      final fp = _portalLogPath();
      if (!await fileExists(fp)) return const <Map<String, dynamic>>[];

      final lines = await readLines(fp);
      final out = <Map<String, dynamic>>[];
      for (final line in lines.reversed) {
        if (line.trim().isEmpty) continue;
        out.add(jsonDecode(line) as Map<String, dynamic>);
        if (out.length >= limit) break;
      }
      return out;
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  /* ======================= Exports ======================= */

  Future<void> _exportDeliverablePack() async {
    if (_busy) return;
    if (kIsWeb) {
      _snack('Deliverable pack export is disabled on web demo.');
      return;
    }

    setState(() => _busy = true);
    try {
      final res = await DeliverablePackExporter.exportPdf(
        store: widget.store,
        engagementId: widget.engagementId,
      );
      _snack('Saved: ${res.savedFileName} ✅');
      await _refresh();
    } catch (e) {
      _snack('Deliverable pack failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportClientPortalAuditTrail() async {
    if (_busy) return;
    if (kIsWeb) {
      _snack('Audit trail export is disabled on web demo.');
      return;
    }

    setState(() => _busy = true);
    try {
      final res = await ClientPortalAuditExporter.exportPdf(
        store: widget.store,
        engagementId: widget.engagementId,
      );
      _snack('Audit trail exported ✅ (${res.savedFileName})');
      await _refresh();
    } catch (e) {
      _snack('Audit trail export failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportIntegrityCertificate(_Vm vm) async {
    if (_busy) return;
    if (kIsWeb) {
      _snack('Certificate export is disabled on web demo.');
      return;
    }

    setState(() => _busy = true);
    try {
      final res = await EvidenceIntegrityCertificateExporter.exportPdf(
        engagementId: widget.engagementId,
        engagementTitle: vm.engagement.title,
        clientName: vm.clientName,
      );
      _snack('Certificate exported ✅ (${res.savedFileName})');
      await _refresh();
    } catch (e) {
      _snack('Certificate export failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // STOP HERE — PART 2 continues with _load(), build(), and widget classes
    /* ======================= PBC reading ======================= */

  Future<_PbcCounts> _readPbcCounts(String docsPath, String engagementId) async {
    if (!_canFile) return const _PbcCounts();
    try {
      final fp = p.join(docsPath, 'Auditron', 'PBC', '$engagementId.json');
      if (!await fileExists(fp)) return const _PbcCounts();

      final raw = await readTextFile(fp);
      if (raw.trim().isEmpty) return const _PbcCounts();

      final data = jsonDecode(raw) as Map<String, dynamic>;
      final items = (data['items'] as List<dynamic>? ?? <dynamic>[]);

      int requested = 0, received = 0, reviewed = 0;
      for (final it in items) {
        if (it is! Map) continue;
        final s = (it['status'] ?? '').toString().toLowerCase();
        if (s == 'requested') requested++;
        if (s == 'received') received++;
        if (s == 'reviewed') reviewed++;
      }

      return _PbcCounts(requested: requested, received: received, reviewed: reviewed);
    } catch (_) {
      return const _PbcCounts();
    }
  }

  Future<int> _readPbcOverdueCount(String docsPath, String engagementId) async {
    if (!_canFile) return 0;
    try {
      final fp = p.join(docsPath, 'Auditron', 'PBC', '$engagementId.json');
      if (!await fileExists(fp)) return 0;

      final raw = await readTextFile(fp);
      if (raw.trim().isEmpty) return 0;

      final data = jsonDecode(raw) as Map<String, dynamic>;
      final items = (data['items'] as List<dynamic>? ?? <dynamic>[]);

      int overdue = 0;
      for (final it in items) {
        if (it is! Map) continue;

        final status = (it['status'] ?? '').toString().toLowerCase();
        if (status != 'requested') continue;

        final requestedAt = (it['requestedAt'] ?? '').toString().trim();
        final dt = DateTime.tryParse(requestedAt);
        if (dt == null) continue;

        if (DateTime.now().difference(dt).inDays >= 7) overdue++;
      }
      return overdue;
    } catch (_) {
      return 0;
    }
  }

  /* ======================= Integrity quick check ======================= */

  Future<int> _integrityIssuesForEngagement({
    required String engagementId,
    int maxEntriesToCheck = 10,
  }) async {
    if (kIsWeb) return 0;
    try {
      final entries = await EvidenceLedger.readAll(engagementId);
      if (entries.isEmpty) return 0;

      final toCheck = entries.reversed.take(maxEntriesToCheck);
      int issues = 0;
      for (final e in toCheck) {
        final res = await EvidenceLedger.verifyEntry(e);
        if (!res.exists || !res.hashMatches) issues++;
      }
      return issues;
    } catch (_) {
      return 0;
    }
  }

  /* ======================= Load + Refresh ======================= */

  Future<_Vm> _load() async {
    final eng = await _engRepo.getById(widget.engagementId);
    if (eng == null) {
      throw StateError('Engagement not found: ${widget.engagementId}');
    }

    final client = await _clientsRepo.getById(eng.clientId);
    final clientName = client?.name ?? eng.clientId;

    final risk = await _riskRepo.ensureForEngagement(eng.id);
    final workpapers = await _wpRepo.getByEngagementId(eng.id);

    final pbcCounts = await _readPbcCounts(_docsPath, eng.id);
    final pbcOverdue = await _readPbcOverdueCount(_docsPath, eng.id);

    final totalWps = workpapers.length;
    final completeWps = workpapers.where((w) => w.status.trim().toLowerCase() == 'complete').length;
    final openWps = (totalWps - completeWps).clamp(0, 999999);

    final lettersGenerated = (!_canFile)
        ? 0
        : await LetterExporter.getLettersGeneratedCount(
            docsPath: _docsPath,
            engagementId: eng.id,
          );

    final integrityIssues = await _integrityIssuesForEngagement(engagementId: eng.id);

    final disc = await _discRepo.summary(widget.engagementId);

    final readinessPct = _computeReadinessPercentV2(
      riskCompleted: risk.updated.trim().isNotEmpty,
      planningCompleted: false,
      pbcProgress01: pbcCounts.progress01,
      totalWorkpapers: totalWps,
      completeWorkpapers: completeWps,
      lettersGenerated: lettersGenerated,
    );

    final health = _computeHealth(
      engagementStatus: eng.status,
      riskLevel: risk.overallLevel(),
      openWorkpapers: openWps,
    );

    final pin = await _readPinOrEmpty();

    final exports = await ExportHistoryReader.load(widget.store, widget.engagementId);
    final aiHistory = await AiPriorityHistoryStore.read(widget.store, widget.engagementId);

    return _Vm(
      engagement: eng,
      clientName: clientName,
      risk: risk,
      workpapers: workpapers,
      lettersGenerated: lettersGenerated,
      pbcRequested: pbcCounts.requested,
      pbcReceived: pbcCounts.received,
      pbcReviewed: pbcCounts.reviewed,
      pbcOverdueCount: pbcOverdue,
      totalWorkpapers: totalWps,
      openWorkpapers: openWps,
      readinessPct: readinessPct,
      integrityIssues: integrityIssues,
      healthLabel: health.label,
      healthTone: health.tone,
      clientPortalPin: pin,
      canUseFileSystem: _canFile,
      exportHistory: exports,
      aiPriorityHistory: aiHistory,
      discrepancyOpenCount: disc.openCount,
      discrepancyOpenTotal: disc.openTotal,
    );
  }

  Future<void> _refresh() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _engRepo.clearCache();
      await _clientsRepo.clearCache();
      await _wpRepo.clearCache();
      await _riskRepo.clearCache();
      setState(() => _future = _load());
      await _future;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /* ======================= Navigation ======================= */

  void _openClientPortal() => context.pushNamed('clientPortal', pathParameters: {'id': widget.engagementId});
  void _openPbc() => context.pushNamed('pbcList', pathParameters: {'id': widget.engagementId});
  void _openLetters() => context.pushNamed('lettersHub', pathParameters: {'id': widget.engagementId});
  void _openPlanning() => context.pushNamed('engagementPlanning', pathParameters: {'id': widget.engagementId});
  void _openPacket() => context.pushNamed('engagementPacket', pathParameters: {'id': widget.engagementId});
  void _openDiscrepancies() => context.pushNamed('engagementDiscrepancies', pathParameters: {'id': widget.engagementId});

  Future<void> _addWorkpaper() async {
    if (_busy) return;

    final created = await showDialog<WorkpaperModel>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AddWorkpaperDialog(engagementId: widget.engagementId),
    );
    if (created == null) return;

    setState(() => _busy = true);
    try {
      await _wpRepo.upsert(created);
      _changed = true;
      _snack('Workpaper added ✅');
      await _refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget? _lettersGeneratedPill(_Vm vm, ColorScheme cs) {
    if (vm.lettersGenerated <= 0) return null;
    return _Pill(
      text: '${vm.lettersGenerated} generated',
      bg: cs.secondaryContainer,
      border: cs.secondary.withOpacity(0.35),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return WillPopScope(
      onWillPop: () async {
        context.pop(_changed);
        return false;
      },
      child: FutureBuilder<_Vm>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snap.hasError) {
            return Scaffold(
              appBar: AppBar(title: const Text('Engagement')),
              body: _ErrorState(
                title: 'Failed to load engagement',
                message: snap.error.toString(),
                onRetry: _busy ? null : _refresh,
              ),
            );
          }

          final vm = snap.data!;
          final isFinalized = vm.engagement.status.trim().toLowerCase() == 'finalized';
          final hc = _healthColors(context, vm.healthTone);

          void finalizedMsg() => _snack('Engagement is finalized — portal is closed.');

          final pinStatusPill = vm.clientPortalPin.trim().isNotEmpty
              ? _Pill(text: 'PIN ACTIVE', bg: cs.secondaryContainer, border: cs.secondary.withOpacity(0.35))
              : _Pill(text: 'PIN NOT SET', bg: cs.surfaceContainerHighest, border: cs.onSurface.withOpacity(0.12));

          final portalClosedPill = isFinalized
              ? _Pill(text: 'PORTAL CLOSED', bg: cs.surfaceContainerHighest, border: cs.onSurface.withOpacity(0.12))
              : null;

          final portalLink = '/engagements/${widget.engagementId}/client-portal?pin=${vm.clientPortalPin}';

          return Scaffold(
            appBar: AppBar(
              title: const Text('Engagement'),
              leading: IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(_changed),
              ),
              actions: [
                IconButton(
                  tooltip: isFinalized ? 'Portal closed (finalized)' : 'Copy Client Portal Invite',
                  onPressed: isFinalized ? finalizedMsg : _copyPortalInvite,
                  icon: const Icon(Icons.share_outlined),
                ),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: _busy ? null : _refresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              children: [
                if (!vm.canUseFileSystem)
                  Card(
                    color: cs.surfaceContainerHighest,
                    child: const ListTile(
                      leading: Icon(Icons.public),
                      title: Text('Web demo mode'),
                      subtitle: Text('File-backed features are disabled on web (exports, portal logs, PIN storage).'),
                    ),
                  ),
                if (!vm.canUseFileSystem) const SizedBox(height: 12),

                _HeaderCard(
                  icon: Icons.work_outline,
                  title: vm.engagement.title,
                  subtitle: 'Client: ${vm.clientName}',
                  trailing: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _Pill(
                        text: vm.engagement.status,
                        bg: cs.primary.withOpacity(0.14),
                        border: cs.primary.withOpacity(0.35),
                      ),
                      const SizedBox(height: 8),
                      _Pill(text: 'Health: ${vm.healthLabel}', bg: hc.bg, border: hc.border),
                      const SizedBox(height: 8),
                      _Pill(
                        text: 'Ready: ${vm.readinessPct}%',
                        bg: cs.secondaryContainer,
                        border: cs.secondary.withOpacity(0.35),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Export History
                Card(
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
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _Pill(
                              text: 'Deliverables: ${vm.exportHistory.deliverablePackCount}',
                              bg: cs.surfaceContainerHighest,
                              border: cs.onSurface.withOpacity(0.10),
                            ),
                            _Pill(
                              text: 'Packets: ${vm.exportHistory.auditPacketCount}',
                              bg: cs.surfaceContainerHighest,
                              border: cs.onSurface.withOpacity(0.10),
                            ),
                            _Pill(
                              text: 'Certificates: ${vm.exportHistory.integrityCertCount}',
                              bg: cs.surfaceContainerHighest,
                              border: cs.onSurface.withOpacity(0.10),
                            ),
                            _Pill(
                              text: 'Portal Trails: ${vm.exportHistory.portalAuditCount}',
                              bg: cs.surfaceContainerHighest,
                              border: cs.onSurface.withOpacity(0.10),
                            ),
                            _Pill(
                              text: 'Letters: ${vm.exportHistory.lettersCount}',
                              bg: cs.surfaceContainerHighest,
                              border: cs.onSurface.withOpacity(0.10),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Last deliverable: ${_prettyIsoShort(vm.exportHistory.deliverableLastIso)}\n'
                          'Last packet: ${_prettyIsoShort(vm.exportHistory.packetLastIso)}\n'
                          'Last certificate: ${_prettyIsoShort(vm.exportHistory.certLastIso)}\n'
                          'Last portal trail: ${_prettyIsoShort(vm.exportHistory.portalAuditLastIso)}\n'
                          'Last letter: ${_prettyIsoShort(vm.exportHistory.lettersLastIso)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: cs.onSurface.withOpacity(0.70),
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // AI Priority Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Builder(
                      builder: (context) {
                        final ai = _computeAiPreview(vm);

                        Color bg = cs.surfaceContainerHighest;
                        Color border = cs.onSurface.withOpacity(0.12);

                        switch (ai.label.toLowerCase()) {
                          case 'critical':
                            bg = cs.errorContainer;
                            border = cs.error.withOpacity(0.35);
                            break;
                          case 'high':
                            bg = cs.tertiaryContainer;
                            border = cs.tertiary.withOpacity(0.35);
                            break;
                          case 'medium':
                            bg = cs.surfaceContainerHighest;
                            border = cs.onSurface.withOpacity(0.12);
                            break;
                          case 'low':
                          default:
                            bg = cs.secondaryContainer;
                            border = cs.secondary.withOpacity(0.35);
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AI Priority',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.2,
                                  ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _Pill(
                                  text: '${ai.label.toUpperCase()} (${ai.score})',
                                  bg: bg,
                                  border: border,
                                ),
                                if (vm.engagement.aiPriorityUpdatedAt.trim().isNotEmpty)
                                  _Pill(
                                    text: 'Saved',
                                    bg: cs.surfaceContainerHighest,
                                    border: cs.onSurface.withOpacity(0.10),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              ai.reason.isEmpty ? '—' : ai.reason,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: cs.onSurface.withOpacity(0.70),
                                  ),
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: _busy ? null : () => _refreshAiPriority(vm),
                              icon: const Icon(Icons.auto_awesome),
                              label: Text(vm.engagement.hasAiPriority ? 'Refresh AI Priority' : 'Generate AI Priority'),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // AI Priority History
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(top: 10),
                      title: Text(
                        'AI Priority History (${vm.aiPriorityHistory.length})',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.2,
                            ),
                      ),
                      subtitle: Text(
                        vm.aiPriorityHistory.isEmpty ? 'No saved history yet.' : 'Newest first (last 30).',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSurface.withOpacity(0.70),
                            ),
                      ),
                      children: [
                        if (vm.aiPriorityHistory.isEmpty)
                          Text(
                            'Generate & Save AI Priority to start a history trail.',
                            style: Theme.of(context).textTheme.bodySmall,
                          )
                        else
                          ...vm.aiPriorityHistory.map(
                            (h) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: cs.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: cs.onSurface.withOpacity(0.10)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${h.label} (${h.score}) • ${_prettyIsoShort(h.atIso)}',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      h.reason.isEmpty ? '—' : h.reason,
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: cs.onSurface.withOpacity(0.70),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // AI Copilot (Local)
                AiCopilotCard(
                  onSummarize: () => AiCopilotLocal.summarize(
                    engagement: vm.engagement,
                    clientName: vm.clientName,
                    risk: vm.risk,
                    openWorkpapers: vm.openWorkpapers,
                    totalWorkpapers: vm.totalWorkpapers,
                    pbcOverdueCount: vm.pbcOverdueCount,
                    discrepancyOpenCount: vm.discrepancyOpenCount,
                    discrepancyOpenTotal: vm.discrepancyOpenTotal,
                    integrityIssues: vm.integrityIssues,
                    readinessPct: vm.readinessPct,
                  ),
                  onNextActions: () => AiCopilotLocal.nextActions(
                    risk: vm.risk,
                    openWorkpapers: vm.openWorkpapers,
                    pbcOverdueCount: vm.pbcOverdueCount,
                    discrepancyOpenCount: vm.discrepancyOpenCount,
                    integrityIssues: vm.integrityIssues,
                  ),
                  onDraftPbcEmail: () => AiCopilotLocal.draftPbcEmail(
                    engagementId: widget.engagementId,
                    clientName: vm.clientName,
                    overdueCount: vm.pbcOverdueCount,
                    portalLink: portalLink,
                    pin: vm.clientPortalPin,
                  ),
                  onExplainPriority: () => AiCopilotLocal.explainAiPriority(
                    label: vm.engagement.aiPriorityLabel.isEmpty ? 'Medium' : vm.engagement.aiPriorityLabel,
                    score: vm.engagement.aiPriorityScore,
                    reason: vm.engagement.aiPriorityReason.isEmpty ? '—' : vm.engagement.aiPriorityReason,
                  ),
                ),
                const SizedBox(height: 12),

                // Total Discrepancy quick view + button
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _Pill(
                          text: '${vm.discrepancyOpenCount} open',
                          bg: cs.surfaceContainerHighest,
                          border: cs.onSurface.withOpacity(0.10),
                        ),
                        _Pill(
                          text: '\$${vm.discrepancyOpenTotal.toStringAsFixed(2)} total',
                          bg: cs.surfaceContainerHighest,
                          border: cs.onSurface.withOpacity(0.10),
                        ),
                        FilledButton.icon(
                          onPressed: _openDiscrepancies,
                          icon: const Icon(Icons.rule_folder_outlined),
                          label: const Text('Discrepancies'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                if (vm.integrityIssues > 0) ...[
                  Card(
                    color: cs.errorContainer,
                    child: ListTile(
                      leading: const Icon(Icons.warning_amber_outlined),
                      title: Text('Evidence integrity alert (${vm.integrityIssues})'),
                      subtitle: const Text('Tap to review evidence ledger.'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final ctx = _ledgerKey.currentContext;
                        if (ctx != null) {
                          await Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 250));
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                _RiskSummaryCard(
                  risk: vm.risk,
                  onOpen: () => context.pushNamed('engagementRisk', pathParameters: {'id': widget.engagementId}),
                  extraLine: vm.totalWorkpapers == 0 ? 'No workpapers' : '${vm.openWorkpapers} open • ${vm.totalWorkpapers} total',
                  healthPill: _Pill(text: vm.healthLabel, bg: hc.bg, border: hc.border),
                ),
                const SizedBox(height: 12),

                AuditTimelineCard(
                  engagementId: widget.engagementId,
                  onScrollToLedger: () async {
                    final ctx = _ledgerKey.currentContext;
                    if (ctx != null) {
                      await Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 250));
                    }
                  },
                ),
                const SizedBox(height: 12),

                ExportHistoryCard(
                  store: widget.store,
                  engagementId: widget.engagementId,
                ),
                const SizedBox(height: 12),

                Container(
                  key: _ledgerKey,
                  child: EvidenceLedgerCard(engagementId: widget.engagementId),
                ),

                IntegrityStatusCard(
                  engagementId: widget.engagementId,
                  onTapOpenLedger: () async {
                    final ctx = _ledgerKey.currentContext;
                    if (ctx != null) {
                      await Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 250));
                    }
                },
                   onExportCertificate: () async {
                     final vm = await _future;
                     await _exportIntegrityCertificate(vm);
                   },
                ),
                const SizedBox(height: 12),

                Container(
                  key: _ledgerKey,
                  child: EvidenceLedgerCard(engagementId: widget.engagementId),
                ),
                const SizedBox(height: 14),

                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _readPortalLog(limit: 10),
                  builder: (context, logSnap) {
                    if (!logSnap.hasData || logSnap.data!.isEmpty) return const SizedBox.shrink();
                    final logs = logSnap.data!;
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Client Portal Activity',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.2,
                                  ),
                            ),
                            const SizedBox(height: 10),
                            ...logs.map((e) {
                              final title = (e['itemTitle'] ?? 'Document').toString();
                              final createdAt = (e['createdAt'] ?? '').toString();
                              final when = DateTime.tryParse(createdAt) ?? DateTime.fromMillisecondsSinceEpoch(0);
                              final sha = (e['sha256'] ?? '').toString();
                              final shaShort = sha.isEmpty ? '—' : '${sha.substring(0, min(12, sha.length))}…';

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Uploaded: $title',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_prettyWhen(when)} • SHA $shaShort',
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),

                Text('Actions', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),

                _ActionCard(
                  icon: Icons.inventory_2_outlined,
                  title: 'Deliverable Pack',
                  subtitle: kIsWeb ? 'Disabled on web demo' : 'One-click client-ready PDF bundle',
                  onTap: _exportDeliverablePack,
                ),
                const SizedBox(height: 10),

                _ActionCard(
                  icon: Icons.receipt_long_outlined,
                  title: 'Client Portal Audit Trail',
                  subtitle: kIsWeb ? 'Disabled on web demo' : 'Export portal upload activity + integrity verification',
                  onTap: _exportClientPortalAuditTrail,
                ),
                const SizedBox(height: 10),

                _ActionCard(
                  icon: Icons.verified_outlined,
                  title: 'Evidence Integrity Certificate',
                  subtitle: kIsWeb ? 'Disabled on web demo' : 'Export a certificate showing evidence verification',
                  onTap: () => _exportIntegrityCertificate(vm),
                ),
                const SizedBox(height: 10),

                _ActionCard(
                  icon: Icons.open_in_new_outlined,
                  title: 'Client Portal',
                  subtitle: isFinalized ? 'Portal closed (finalized)' : 'Client uploads evidence here',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      pinStatusPill,
                      if (portalClosedPill != null) ...[
                        const SizedBox(width: 6),
                        portalClosedPill,
                      ],
                    ],
                  ),
                  onTap: isFinalized ? finalizedMsg : _openClientPortal,
                ),
                const SizedBox(height: 10),

                _ActionCard(
                  icon: Icons.share_outlined,
                  title: 'Share Client Portal',
                  subtitle: isFinalized ? 'Disabled (finalized)' : (vm.canUseFileSystem ? 'Tap to copy' : 'Disabled on web demo'),
                  onTap: isFinalized ? finalizedMsg : _copyPortalInvite,
                ),
                const SizedBox(height: 10),

                _ActionCard(
                  icon: Icons.lock_reset_outlined,
                  title: 'Regenerate PIN',
                  subtitle: isFinalized ? 'Disabled (finalized)' : (vm.canUseFileSystem ? 'Invalidate old PIN + copy new' : 'Disabled on web demo'),
                  onTap: isFinalized ? finalizedMsg : _regeneratePin,
                ),
                const SizedBox(height: 10),

                _ActionCard(
                  icon: Icons.assignment_outlined,
                  title: 'Audit Planning Summary',
                  subtitle: 'Open planning summary',
                  onTap: _openPlanning,
                ),
                const SizedBox(height: 10),

                _ActionCard(
                  icon: Icons.picture_as_pdf_outlined,
                  title: 'Audit Packet',
                  subtitle: 'Open packet export',
                  onTap: _openPacket,
                ),
                const SizedBox(height: 10),

                _ActionCard(
                  icon: Icons.mail_outline,
                  title: 'Letters',
                  subtitle: 'AICPA-aligned letters',
                  trailing: _lettersGeneratedPill(vm, cs),
                  onTap: _openLetters,
                ),
                const SizedBox(height: 10),

                _ActionCard(
                  icon: Icons.fact_check_outlined,
                  title: 'PBC Builder',
                  subtitle: 'Requests • evidence • reminders',
                  onTap: _openPbc,
                ),
                const SizedBox(height: 18),

                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Workpapers',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.2,
                            ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _busy ? null : _addWorkpaper,
                      icon: const Icon(Icons.add),
                      label: const Text('Add'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                if (vm.workpapers.isEmpty)
                  _EmptyState(
                    icon: Icons.folder_open_outlined,
                    title: 'No workpapers yet',
                    subtitle: 'Add your first workpaper to start organizing evidence.',
                  )
                else
                  ...vm.workpapers.map(
                    (wp) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _WorkpaperRow(
                        workpaper: wp,
                        onOpen: () => context.pushNamed('workpaperDetail', pathParameters: {'id': wp.id}),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
} // ✅ END OF STATE CLASS

/* ======================= VM / Models ======================= */

class _Vm {
  final EngagementModel engagement;
  final String clientName;
  final RiskAssessmentModel risk;
  final List<WorkpaperModel> workpapers;

  final int lettersGenerated;

  final int pbcRequested;
  final int pbcReceived;
  final int pbcReviewed;
  final int pbcOverdueCount;

  final int totalWorkpapers;
  final int openWorkpapers;

  final int readinessPct;
  final int integrityIssues;

  final String healthLabel;
  final _HealthTone healthTone;

  final String clientPortalPin;
  final bool canUseFileSystem;

  final ExportHistoryVm exportHistory;
  final List<AiPriorityHistoryEntry> aiPriorityHistory;

  final int discrepancyOpenCount;
  final double discrepancyOpenTotal;

  const _Vm({
    required this.engagement,
    required this.clientName,
    required this.risk,
    required this.workpapers,
    required this.lettersGenerated,
    required this.pbcRequested,
    required this.pbcReceived,
    required this.pbcReviewed,
    required this.pbcOverdueCount,
    required this.totalWorkpapers,
    required this.openWorkpapers,
    required this.readinessPct,
    required this.integrityIssues,
    required this.healthLabel,
    required this.healthTone,
    required this.clientPortalPin,
    required this.canUseFileSystem,
    required this.exportHistory,
    required this.aiPriorityHistory,
    required this.discrepancyOpenCount,
    required this.discrepancyOpenTotal,
  });
}

class _PbcCounts {
  final int requested;
  final int received;
  final int reviewed;

  const _PbcCounts({
    this.requested = 0,
    this.received = 0,
    this.reviewed = 0,
  });

  int get total => requested + received + reviewed;

  double get progress01 {
    final t = total;
    if (t <= 0) return 0;
    return (received + reviewed) / t;
  }
}

/* ======================= Readiness + Health ======================= */

int _computeReadinessPercentV2({
  required bool riskCompleted,
  required bool planningCompleted,
  required double pbcProgress01,
  required int totalWorkpapers,
  required int completeWorkpapers,
  required int lettersGenerated,
}) {
  final risk = riskCompleted ? 20 : 0;
  final planning = planningCompleted ? 20 : 0;
  final wp = totalWorkpapers <= 0 ? 0 : ((completeWorkpapers / totalWorkpapers) * 30).round();
  final letters = lettersGenerated > 0 ? 10 : 0;
  final pbc = (pbcProgress01.clamp(0, 1) * 20).round();
  return (risk + planning + wp + letters + pbc).clamp(0, 99);
}

enum _HealthTone { healthy, attention, risk, finalized, unknown }

class _HealthResult {
  final String label;
  final _HealthTone tone;
  const _HealthResult(this.label, this.tone);
}

_HealthResult _computeHealth({
  required String engagementStatus,
  required String riskLevel,
  required int openWorkpapers,
}) {
  final status = engagementStatus.trim().toLowerCase();
  if (status == 'finalized') return const _HealthResult('Finalized', _HealthTone.finalized);

  final risk = riskLevel.trim().toLowerCase();
  if (risk.contains('high')) return const _HealthResult('At Risk', _HealthTone.risk);

  if (risk.contains('medium')) {
    return _HealthResult(openWorkpapers > 0 ? 'Needs Attention' : 'Monitor', _HealthTone.attention);
  }

  if (openWorkpapers > 0) return const _HealthResult('In Progress', _HealthTone.attention);
  if (risk.contains('low')) return const _HealthResult('Healthy', _HealthTone.healthy);

  return const _HealthResult('—', _HealthTone.unknown);
}

class _HealthColors {
  final Color bg;
  final Color border;
  const _HealthColors(this.bg, this.border);
}

_HealthColors _healthColors(BuildContext context, _HealthTone tone) {
  final cs = Theme.of(context).colorScheme;
  switch (tone) {
    case _HealthTone.healthy:
      return _HealthColors(cs.secondaryContainer, cs.secondary.withOpacity(0.40));
    case _HealthTone.attention:
      return _HealthColors(cs.tertiaryContainer, cs.tertiary.withOpacity(0.40));
    case _HealthTone.risk:
      return _HealthColors(cs.errorContainer, cs.error.withOpacity(0.40));
    case _HealthTone.finalized:
      return _HealthColors(cs.surfaceContainerHighest, cs.onSurface.withOpacity(0.12));
    case _HealthTone.unknown:
      return _HealthColors(cs.surfaceContainerHighest, cs.onSurface.withOpacity(0.10));
  }
}

String _prettyWhen(DateTime dt) {
  if (dt.millisecondsSinceEpoch == 0) return '—';
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

/* ======================= UI Widgets ======================= */

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: cs.primary.withOpacity(0.14),
                border: Border.all(color: cs.onSurface.withOpacity(0.08)),
              ),
              child: Icon(icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: -0.2),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withOpacity(0.70),
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cs.onSurface.withOpacity(0.08)),
                ),
                child: Icon(icon, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: -0.2)),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withOpacity(0.70),
                        ),
                  ),
                ]),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 10),
                trailing!,
              ],
              Icon(Icons.chevron_right, color: cs.onSurface.withOpacity(0.55)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RiskSummaryCard extends StatelessWidget {
  const _RiskSummaryCard({
    required this.risk,
    required this.onOpen,
    required this.extraLine,
    required this.healthPill,
  });

  final RiskAssessmentModel risk;
  final VoidCallback onOpen;
  final String extraLine;
  final Widget healthPill;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final level = risk.overallLevel();
    final score = risk.overallScore1to5();
    final assessed = risk.updated.trim().isEmpty ? '—' : risk.updated.trim();

    Color bg = cs.surfaceContainerHighest;
    Color border = cs.onSurface.withOpacity(0.10);

    final l = level.toLowerCase();
    if (l.contains('high')) {
      bg = cs.errorContainer;
      border = cs.error.withOpacity(0.40);
    } else if (l.contains('medium')) {
      bg = cs.tertiaryContainer;
      border = cs.tertiary.withOpacity(0.40);
    } else if (l.contains('low')) {
      bg = cs.secondaryContainer;
      border = cs.secondary.withOpacity(0.40);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.shield_outlined),
            const SizedBox(width: 10),
            Expanded(
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _Pill(text: 'Overall: $level ($score/5)', bg: bg, border: border),
                  healthPill,
                  _Pill(
                    text: 'Last assessed: $assessed',
                    bg: cs.surfaceContainerHighest,
                    border: cs.onSurface.withOpacity(0.10),
                  ),
                  _Pill(
                    text: extraLine,
                    bg: cs.surfaceContainerHighest,
                    border: cs.onSurface.withOpacity(0.10),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.chevron_right),
              label: const Text('Open'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkpaperRow extends StatelessWidget {
  const _WorkpaperRow({
    required this.workpaper,
    required this.onOpen,
  });

  final WorkpaperModel workpaper;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cs.onSurface.withOpacity(0.08)),
                ),
                child: const Icon(Icons.folder_open_outlined, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  workpaper.title,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: -0.2),
                ),
              ),
              Icon(Icons.chevron_right, color: cs.onSurface.withOpacity(0.55)),
            ],
          ),
        ),
      ),
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
        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 46),
            const SizedBox(height: 10),
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(subtitle, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.title, required this.message, required this.onRetry});
  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 60),
        const Icon(Icons.error_outline, size: 44),
        const SizedBox(height: 10),
        Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(message, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Try again'),
        ),
      ],
    );
  }
}

class _AddWorkpaperDialog extends StatefulWidget {
  const _AddWorkpaperDialog({required this.engagementId});
  final String engagementId;

  @override
  State<_AddWorkpaperDialog> createState() => _AddWorkpaperDialogState();
}

class _AddWorkpaperDialogState extends State<_AddWorkpaperDialog> {
  final _titleCtrl = TextEditingController();
  final List<String> _statusOptions = const ['Open', 'In Progress', 'Complete'];
  final List<String> _typeOptions = const ['xlsx', 'pdf', 'docx'];

  String _status = 'Open';
  String _type = 'xlsx';

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;

    Navigator.of(context).pop(
      WorkpaperModel(
        id: '',
        engagementId: widget.engagementId,
        title: title,
        status: _status,
        updated: '',
        type: _type,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Workpaper'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _status,
              items: _statusOptions.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (v) => setState(() => _status = v ?? _status),
              decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _type,
              items: _typeOptions.map((v) => DropdownMenuItem(value: v, child: Text(v.toUpperCase()))).toList(),
              onChanged: (v) => setState(() => _type = v ?? _type),
              decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Create')),
      ],
    );
  }
}