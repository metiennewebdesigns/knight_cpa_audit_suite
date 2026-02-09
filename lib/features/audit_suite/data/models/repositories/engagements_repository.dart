import 'dart:convert';
import 'package:flutter/services.dart';

import '../../../../../core/storage/local_store.dart';
import '../engagement_models.dart';
import '../permissions.dart';
import '../repositories/session_repository.dart';

class EngagementsRepository {
  EngagementsRepository(this.store);

  final LocalStore store;

  static const _cacheKey = 'demo_engagements_cache_v1';
  List<EngagementModel>? _memoryCache;

  SessionRepository get _session => SessionRepository(store);

  Future<List<EngagementModel>> getEngagements() async {
    if (_memoryCache != null) return _memoryCache!;

    final cached = store.prefs.getString(_cacheKey);
    if (cached != null && cached.trim().isNotEmpty) {
      final decoded = jsonDecode(cached) as List<dynamic>;
      _memoryCache = decoded.map((e) => EngagementModel.fromJson(e as Map<String, dynamic>)).toList();
      return _memoryCache!;
    }

    final seed = await _loadSeed();
    final list = (seed['engagements'] as List<dynamic>? ?? const <dynamic>[])
        .map((e) => EngagementModel.fromJson(e as Map<String, dynamic>))
        .toList();

    _memoryCache = list;
    await _persist(list);
    return list;
  }

  Future<EngagementModel?> getById(String id) async {
    final list = await getEngagements();
    try {
      return list.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<EngagementModel> upsert(EngagementModel draft) async {
    final role = _session.current.role;

    // If they're trying to set status Finalized, only CPA/Admin
    final wantsFinalize = draft.status.trim().toLowerCase() == 'finalized';
    if (wantsFinalize) {
      Permissions.require(
        Permissions.canFinalizeEngagement(role),
        'Permission denied: Only CPA/Admin can finalize engagements.',
      );
    } else {
      Permissions.require(
        Permissions.canCreateEditDeleteEngagement(role),
        'Permission denied: Client users cannot create or edit engagements.',
      );
    }

    final list = [...await getEngagements()];

    final id = draft.id.trim().isEmpty ? _newId() : draft.id.trim();
    final normalized = draft.copyWith(
      id: id,
      updated: draft.updated.trim().isEmpty ? _todayIso() : draft.updated.trim(),
    );

    final idx = list.indexWhere((e) => e.id == id);
    if (idx >= 0) {
      list[idx] = normalized;
    } else {
      list.add(normalized);
    }

    _memoryCache = list;
    await _persist(list);
    return normalized;
  }

  Future<void> deleteById(String id) async {
    final role = _session.current.role;
    Permissions.require(
      Permissions.canCreateEditDeleteEngagement(role),
      'Permission denied: Client users cannot delete engagements.',
    );

    final list = [...await getEngagements()];
    list.removeWhere((e) => e.id == id);

    _memoryCache = list;
    await _persist(list);
  }

  Future<void> clearCache() async {
    _memoryCache = null;
  }

  Future<void> resetDemo() async {
    _memoryCache = null;
    await store.prefs.remove(_cacheKey);
  }

  Future<void> _persist(List<EngagementModel> list) async {
    await store.prefs.setString(
      _cacheKey,
      jsonEncode(list.map((e) => e.toJson()).toList()),
    );
  }

  Future<Map<String, dynamic>> _loadSeed() async {
    final raw = await rootBundle.loadString('assets/seed/demo_data.json');
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  String _newId() => 'eng-${DateTime.now().millisecondsSinceEpoch}';

  String _todayIso() {
    final d = DateTime.now();
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }
}