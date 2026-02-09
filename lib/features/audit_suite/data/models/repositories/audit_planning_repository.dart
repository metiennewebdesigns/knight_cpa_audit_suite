import 'dart:convert';

import 'package:flutter/services.dart';

import '../../../../../core/storage/local_store.dart';

import '../audit_planning_models.dart';
import '../risk_assessment_models.dart';
import '../engagement_models.dart';
import '../client_models.dart';
import '../workpaper_models.dart';

import 'clients_repository.dart';
import 'engagements_repository.dart';
import 'risk_assessments_repository.dart';
import 'workpapers_repository.dart';

class AuditPlanningRepository {
  AuditPlanningRepository(this.store);

  final LocalStore store;

  late final ClientsRepository _clientsRepo = ClientsRepository(store);
  late final EngagementsRepository _engRepo = EngagementsRepository(store);
  late final RiskAssessmentsRepository _riskRepo = RiskAssessmentsRepository(store);
  late final WorkpapersRepository _wpRepo = WorkpapersRepository(store);

  static const _cacheKey = 'demo_audit_planning_summary_cache_v1';

  List<AuditPlanningSummaryModel>? _memoryCache;

  Future<List<AuditPlanningSummaryModel>> getAll() async {
    if (_memoryCache != null) return _memoryCache!;

    final cached = store.prefs.getString(_cacheKey);
    if (cached != null && cached.trim().isNotEmpty) {
      final decoded = jsonDecode(cached) as List<dynamic>;
      _memoryCache = decoded
          .map((e) => AuditPlanningSummaryModel.fromJson(e as Map<String, dynamic>))
          .toList();
      return _memoryCache!;
    }

    // start empty (we generate per-engagement)
    _memoryCache = <AuditPlanningSummaryModel>[];
    return _memoryCache!;
  }

  Future<AuditPlanningSummaryModel?> getByEngagementId(String engagementId) async {
    final list = await getAll();
    try {
      return list.firstWhere((x) => x.engagementId == engagementId);
    } catch (_) {
      return null;
    }
  }

  /// ✅ REQUIRED BY YOUR SCREEN
  /// Build a planning summary for a specific engagement.
  Future<AuditPlanningSummaryModel> generate(String engagementId) async {
    // if already exists, return it
    final existing = await getByEngagementId(engagementId);
    if (existing != null) return existing;

    final EngagementModel? eng = await _engRepo.getById(engagementId);
    if (eng == null) {
      throw StateError('Engagement not found: $engagementId');
    }

    final ClientModel? client = await _clientsRepo.getById(eng.clientId);
    final clientName = client?.name ?? eng.clientId;

    final RiskAssessmentModel risk = await _riskRepo.ensureForEngagement(engagementId);

    final workpapers = await _wpRepo.getByEngagementId(engagementId);

    final overallScore = risk.overallScore1to5();
    final overallLevel = risk.overallLevel();

    // pick top risk prompts
    final sorted = List<RiskItemModel>.from(risk.items);
    sorted.sort((a, b) => b.score1to5.compareTo(a.score1to5));
    final top3 = sorted.take(3).map((x) => '• ${x.prompt} (Score ${x.score1to5}/5)').toList();

    final wpLine = workpapers.isEmpty
        ? 'No workpapers have been created yet.'
        : 'Workpapers currently created: ${workpapers.length}.';

    final narrative = [
      'Engagement: ${eng.title} (${eng.id})',
      'Client: $clientName',
      '',
      'Overall risk: $overallLevel ($overallScore/5)',
      '',
      'Top risk drivers:',
      if (top3.isEmpty) '• (none yet)' else ...top3,
      '',
      wpLine,
      '',
      'Planning notes:',
      '• Confirm scope, materiality, and reporting deadlines.',
      if (overallLevel.toLowerCase() == 'high')
        '• Increase sample sizes and add unpredictable procedures.',
      '• Align workpapers to high-risk areas first.',
    ].join('\n');

    final draft = AuditPlanningSummaryModel(
      id: '',
      engagementId: engagementId,
      updated: '',
      overallLevel: overallLevel,
      overallScore1to5: overallScore,
      status: 'Draft',
      narrative: narrative,
    );

    return upsert(draft);
  }

  Future<AuditPlanningSummaryModel> upsert(AuditPlanningSummaryModel draft) async {
    final list = [...await getAll()];

    final id = draft.id.trim().isEmpty ? _newId() : draft.id.trim();
    final normalized = draft.copyWith(
      id: id,
      updated: draft.updated.trim().isEmpty ? _todayIso() : draft.updated.trim(),
    );

    // enforce one per engagement
    list.removeWhere((x) => x.engagementId == normalized.engagementId);
    list.add(normalized);

    _memoryCache = list;
    await _persist(list);
    return normalized;
  }

  /// Clear only memory (keep persisted)
  Future<void> clearCache() async {
    _memoryCache = null;
  }

  /// Reset persisted demo
  Future<void> resetDemo() async {
    _memoryCache = null;
    await store.prefs.remove(_cacheKey);
  }

  Future<void> _persist(List<AuditPlanningSummaryModel> list) async {
    await store.prefs.setString(
      _cacheKey,
      jsonEncode(list.map((e) => e.toJson()).toList()),
    );
  }

  Future<Map<String, dynamic>> _loadSeed() async {
    final raw = await rootBundle.loadString('assets/seed/demo_data.json');
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  String _newId() => 'plan-${DateTime.now().millisecondsSinceEpoch}';

  String _todayIso() {
    final d = DateTime.now();
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }
}