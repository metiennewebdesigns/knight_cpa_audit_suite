import 'dart:convert';

import 'package:flutter/services.dart';

import '../../../../../core/storage/local_store.dart';
import '../risk_assessment_models.dart';

class RiskAssessmentsRepository {
  RiskAssessmentsRepository(this.store);

  final LocalStore store;

  static const _cacheKey = 'demo_risk_assessments_cache_v1';

  List<RiskAssessmentModel>? _memoryCache;

  Future<List<RiskAssessmentModel>> getAll() async {
    // 1) In-memory
    if (_memoryCache != null) return _memoryCache!;

    // 2) SharedPreferences cache (persisted edits)
    final cached = store.prefs.getString(_cacheKey);
    if (cached != null && cached.trim().isNotEmpty) {
      final decoded = jsonDecode(cached) as List<dynamic>;
      _memoryCache = decoded
          .map((e) => RiskAssessmentModel.fromJson(e as Map<String, dynamic>))
          .toList();
      return _memoryCache!;
    }

    // 3) Seed (supports multiple possible keys)
    final seed = await _loadSeed();

    final raw = (seed['risk_assessments'] ??
            seed['riskAssessments'] ??
            seed['risk_assessment'] ??
            const <dynamic>[]) as List<dynamic>;

    final list = raw
        .map((e) => RiskAssessmentModel.fromJson(e as Map<String, dynamic>))
        .toList();

    _memoryCache = list;
    await _persist(list);
    return list;
  }

  Future<RiskAssessmentModel?> getByEngagementId(String engagementId) async {
    final list = await getAll();
    try {
      return list.firstWhere((a) => a.engagementId == engagementId);
    } catch (_) {
      return null;
    }
  }

  /// Ensures there is a RiskAssessment row for an engagement.
  /// If none exists, creates a default one and saves it.
  Future<RiskAssessmentModel> ensureForEngagement(String engagementId) async {
    final existing = await getByEngagementId(engagementId);
    if (existing != null) return existing;

    final created = RiskAssessmentModel.emptyForEngagement(engagementId);
    final saved = await upsert(created);
    return saved;
  }

  Future<RiskAssessmentModel> upsert(RiskAssessmentModel draft) async {
    final list = [...await getAll()];

    final id = draft.id.trim().isEmpty ? _newId() : draft.id.trim();
    final normalized = draft.copyWith(
      id: id,
      updated: draft.updated.trim().isEmpty ? _todayIso() : draft.updated.trim(),
    );

    final idx = list.indexWhere((a) => a.id == id);
    if (idx >= 0) {
      list[idx] = normalized;
    } else {
      list.add(normalized);
    }

    _memoryCache = list;
    await _persist(list);
    return normalized;
  }

  /// ✅ Used for cascade delete: delete the risk assessment for a given engagement
  Future<void> deleteByEngagementId(String engagementId) async {
    final list = [...await getAll()];
    list.removeWhere((a) => a.engagementId == engagementId);

    _memoryCache = list;
    await _persist(list);
  }

  /// ✅ IMPORTANT: clear ONLY memory cache (do not delete persisted edits)
  Future<void> clearCache() async {
    _memoryCache = null;
  }

  /// ⚠️ Deletes persisted edits (reset to seed)
  Future<void> resetDemo() async {
    _memoryCache = null;
    await store.prefs.remove(_cacheKey);
  }

  Future<void> _persist(List<RiskAssessmentModel> list) async {
    await store.prefs.setString(
      _cacheKey,
      jsonEncode(list.map((e) => e.toJson()).toList()),
    );
  }

  Future<Map<String, dynamic>> _loadSeed() async {
    final raw = await rootBundle.loadString('assets/seed/demo_data.json');
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  String _newId() => 'risk-${DateTime.now().millisecondsSinceEpoch}';

  String _todayIso() {
    final d = DateTime.now();
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }
}