import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// PDF
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/storage/local_store.dart';

import '../data/models/engagement_models.dart';
import '../data/models/client_models.dart';
import '../data/models/risk_assessment_models.dart';
import '../data/models/workpaper_models.dart';
import '../data/models/audit_planning_models.dart';

import '../data/models/repositories/engagements_repository.dart';
import '../data/models/repositories/clients_repository.dart';
import '../data/models/repositories/risk_assessments_repository.dart';
import '../data/models/repositories/workpapers_repository.dart';
import '../data/models/repositories/audit_planning_repository.dart';

import '../services/file_save_open.dart';
import '../services/reveal_folder.dart';


class EngagementLetterScreen extends StatefulWidget {
  const EngagementLetterScreen({
    super.key,
    required this.store,
    required this.themeMode,
    required this.engagementId,
  });

  final LocalStore store;
  final ValueNotifier<ThemeMode> themeMode;
  final String engagementId;

  @override
  State<EngagementLetterScreen> createState() => _EngagementLetterScreenState();
}

class _EngagementLetterScreenState extends State<EngagementLetterScreen> {
  late final EngagementsRepository _engRepo;
  late final ClientsRepository _clientsRepo;
  late final RiskAssessmentsRepository _riskRepo;
  late final WorkpapersRepository _wpRepo;
  late final AuditPlanningRepository _planRepo;

  late Future<_Vm> _future;
  bool _busy = false;

  bool get _canFile => !kIsWeb && widget.store.canUseFileSystem;

  final _dateCtrl = TextEditingController();
  final _preparedByCtrl = TextEditingController(text: 'Knight CPA Services');
  final _scopeCtrl = TextEditingController(
    text: 'We will perform audit procedures and provide an audit packet including planning, risk assessment, and workpaper index.',
  );

  @override
  void initState() {
    super.initState();
    _engRepo = EngagementsRepository(widget.store);
    _clientsRepo = ClientsRepository(widget.store);
    _riskRepo = RiskAssessmentsRepository(widget.store);
    _wpRepo = WorkpapersRepository(widget.store);
    _planRepo = AuditPlanningRepository(widget.store);

    _dateCtrl.text = _todayLong();
    _future = _load();
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    _preparedByCtrl.dispose();
    _scopeCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<_Vm> _load() async {
    final eng = await _engRepo.getById(widget.engagementId);
    if (eng == null) throw StateError('Engagement not found: ${widget.engagementId}');

    final client = await _clientsRepo.getById(eng.clientId);
    final risk = await _riskRepo.ensureForEngagement(eng.id);
    final workpapers = await _wpRepo.getByEngagementId(eng.id);
    final planning = await _planRepo.getByEngagementId(eng.id);

    return _Vm(
      engagement: eng,
      client: client,
      risk: risk,
      workpapers: workpapers,
      planning: planning,
    );
  }

  Future<void> _refresh() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _engRepo.clearCache();
      await _clientsRepo.clearCache();
      await _riskRepo.clearCache();
      await _wpRepo.clearCache();
      await _planRepo.clearCache();

      setState(() => _future = _load());
      await _future;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Builds a small contact block, used for UI and PDF.
  List<String> _clientContactLines(ClientModel? client) {
    final taxId = (client?.taxId ?? '').toString().trim();
    final email = (client?.email ?? '').toString().trim();
    final phone = (client?.phone ?? '').toString().trim();

    final out = <String>[];
    if (taxId.isNotEmpty) out.add('Tax ID: $taxId');
    if (email.isNotEmpty) out.add('Email: $email');
    if (phone.isNotEmpty) out.add('Phone: $phone');
    return out;
  }

  Future<List<int>> _buildPdf(_Vm vm) async {
    final doc = pw.Document();

    final eng = vm.engagement;
    final client = vm.client;

    final clientName = (client?.name ?? eng.clientId).toString();
    final clientLocation = (client?.location ?? '').toString().trim();

    final contactLines = _clientContactLines(client);

    final riskLevel = vm.risk.overallLevel();
    final riskScore = vm.risk.overallScore1to5();
    final wpCount = vm.workpapers.length;

    final planningSnippet = (vm.planning?.narrative ?? '').trim();
    final snippet = planningSnippet.isEmpty
        ? 'Planning summary has not been generated yet.'
        : (planningSnippet.length <= 550 ? planningSnippet : '${planningSnippet.substring(0, 550)}…');

    final letterDate = _dateCtrl.text.trim().isEmpty ? _todayLong() : _dateCtrl.text.trim();
    final preparedBy = _preparedByCtrl.text.trim().isEmpty ? 'Knight CPA Services' : _preparedByCtrl.text.trim();
    final scopeText = _scopeCtrl.text.trim().isEmpty ? '—' : _scopeCtrl.text.trim();

    pw.Widget heading(String text) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 10, bottom: 6),
          child: pw.Text(text, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(48),
        build: (_) => [
          pw.Text(preparedBy, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text('Engagement Letter', style: pw.TextStyle(fontSize: 14)),
          pw.SizedBox(height: 14),

          pw.Text(letterDate),
          pw.SizedBox(height: 10),

          // ✅ Client block + contact lines
          pw.Text(clientName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          if (clientLocation.isNotEmpty) pw.Text(clientLocation),
          if (contactLines.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            for (final line in contactLines) pw.Text(line),
          ],
          pw.SizedBox(height: 12),

          pw.Text('Re: ${eng.title}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text('Engagement ID: ${eng.id}'),
          pw.SizedBox(height: 12),

          pw.Text('Dear $clientName,'),
          pw.SizedBox(height: 10),

          pw.Text(
            'This letter confirms our understanding of the scope and objectives of the engagement described above. '
            'We will work with your team to obtain records, perform procedures, and deliver a documented audit packet.',
          ),

          heading('Scope of Services'),
          pw.Text(scopeText),

          heading('Planning Snapshot'),
          pw.Bullet(text: 'Risk level: $riskLevel ($riskScore/5)'),
          pw.Bullet(text: 'Workpapers currently on file: $wpCount'),
          pw.Bullet(text: 'Engagement status: ${eng.status}'),
          pw.SizedBox(height: 6),
          pw.Text('Planning narrative snippet:'),
          pw.SizedBox(height: 4),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(width: 0.5, color: PdfColors.grey400),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Text(snippet, style: const pw.TextStyle(fontSize: 10)),
          ),

          heading('Client Responsibilities'),
          pw.Bullet(text: 'Provide complete and accurate information in a timely manner.'),
          pw.Bullet(text: 'Maintain supporting documentation for transactions and balances.'),
          pw.Bullet(text: 'Designate a point of contact for requests and approvals.'),

          heading('Deliverables'),
          pw.Bullet(text: 'Audit Planning Summary'),
          pw.Bullet(text: 'Pre-Risk Assessment'),
          pw.Bullet(text: 'Workpapers Index and supporting attachments'),
          pw.Bullet(text: 'Audit Packet export (PDF/JSON)'),

          heading('Acceptance'),
          pw.Text('If the above correctly reflects your understanding, please sign and return this letter.'),
          pw.SizedBox(height: 18),

          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Prepared by:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 28),
                    pw.Container(height: 1, color: PdfColors.grey600),
                    pw.SizedBox(height: 4),
                    pw.Text(preparedBy),
                    pw.SizedBox(height: 6),
                    pw.Text('Date: ____________________'),
                  ],
                ),
              ),
              pw.SizedBox(width: 28),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Accepted by:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 28),
                    pw.Container(height: 1, color: PdfColors.grey600),
                    pw.SizedBox(height: 4),
                    pw.Text(clientName),
                    pw.SizedBox(height: 6),
                    pw.Text('Date: ____________________'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return doc.save();
  }

  String _safeFileName(String raw) {
    final cleaned = raw
        .replaceAll(RegExp(r'[\/\\\:\*\?\"\<\>\|]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.isEmpty ? 'EngagementLetter' : cleaned;
  }

  Future<void> _exportPdf() async {
    if (_busy) return;

    if (!_canFile) {
      _snack('Engagement Letter export is disabled on web demo.');
      return;
    }

    setState(() => _busy = true);
    try {
      final vm = await _future;
      final bytes = await _buildPdf(vm);

      final ts = DateTime.now();
      final stamp =
          '${ts.year}${ts.month.toString().padLeft(2, '0')}${ts.day.toString().padLeft(2, '0')}-${ts.hour.toString().padLeft(2, '0')}${ts.minute.toString().padLeft(2, '0')}';

      final baseName = _safeFileName(vm.engagement.title);
      final fileName = 'EngagementLetter-$baseName-${vm.engagement.id}-$stamp.pdf';

      final res = await savePdfBytesAndMaybeOpen(
        fileName: fileName,
        bytes: bytes,
        subfolder: 'Auditron/Letters',
      );

      _snack(res.didOpenFile ? 'Exported + opened ${res.savedFileName} ✅' : 'Exported ${res.savedFileName} ✅');
    } catch (e) {
      _snack('Export failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revealFolder() async {
    if (!_canFile) {
      _snack('Reveal folder is disabled on web demo.');
      return;
    }
    try {
      await revealFolder(subfolder: 'Auditron/Letters');
    } catch (e) {
      _snack('Reveal failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Engagement Letter'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _busy ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: _canFile ? 'Reveal folder' : 'Disabled on web',
            onPressed: _busy ? null : _revealFolder,
            icon: const Icon(Icons.folder_open),
          ),
          IconButton(
            tooltip: _canFile ? 'Export PDF' : 'Disabled on web',
            onPressed: _busy ? null : _exportPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
        ],
      ),
      body: FutureBuilder<_Vm>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const SizedBox(height: 60),
                const Icon(Icons.error_outline, size: 44),
                const SizedBox(height: 10),
                Text('Failed to load letter data.',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(snap.error.toString(), textAlign: TextAlign.center),
              ],
            );
          }

          final vm = snap.data!;
          final clientName = (vm.client?.name ?? vm.engagement.clientId).toString();
          final contactLines = _clientContactLines(vm.client);

          final sub = <String>[
            'Client: $clientName',
            if (contactLines.isNotEmpty) ...contactLines,
            'Engagement ID: ${vm.engagement.id}',
          ].join('\n');

          return AbsorbPointer(
            absorbing: _busy,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (!_canFile)
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.public),
                      title: Text('Web demo mode'),
                      subtitle: Text('Engagement Letter export and folder reveal are disabled on web.'),
                    ),
                  ),
                if (!_canFile) const SizedBox(height: 12),

                Card(
                  child: ListTile(
                    leading: const Icon(Icons.assignment_outlined),
                    title: Text(vm.engagement.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(sub),
                  ),
                ),
                const SizedBox(height: 12),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Letter Settings', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _dateCtrl,
                        decoration: const InputDecoration(labelText: 'Letter Date', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _preparedByCtrl,
                        decoration: const InputDecoration(labelText: 'Prepared By (Firm Name)', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _scopeCtrl,
                        maxLines: 4,
                        decoration: const InputDecoration(labelText: 'Scope of Services (editable)', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _canFile ? _exportPdf : null,
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: Text(_canFile ? 'Export PDF to Documents' : 'Export disabled on web'),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _todayLong() {
    final d = DateTime.now();
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}

class _Vm {
  final EngagementModel engagement;
  final ClientModel? client;
  final RiskAssessmentModel risk;
  final List<WorkpaperModel> workpapers;
  final AuditPlanningSummaryModel? planning;

  const _Vm({
    required this.engagement,
    required this.client,
    required this.risk,
    required this.workpapers,
    required this.planning,
  });
}