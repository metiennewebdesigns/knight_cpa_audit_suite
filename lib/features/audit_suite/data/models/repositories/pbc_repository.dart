import 'dart:convert';
import 'package:flutter/services.dart';

import '../../../../../core/storage/local_store.dart';
import '../pbc_models.dart';
import '../permissions.dart';
import '../repositories/session_repository.dart';

class PbcRepository {
  PbcRepository(this.store);

  final LocalStore store;

  static const _cacheKey = 'demo_pbc_cache_v1';
  List<PbcItemModel>? _memoryCache;

  SessionRepository get _session => SessionRepository(store);

  Future<List<PbcItemModel>> getAll() async {
    if (_memoryCache != null) return _memoryCache!;

    final cached = store.prefs.getString(_cacheKey);
    if (cached != null && cached.trim().isNotEmpty) {
      final decoded = jsonDecode(cached) as List<dynamic>;
      _memoryCache = decoded.map((e) => PbcItemModel.fromJson(e as Map<String, dynamic>)).toList();
      return _memoryCache!;
    }

    final seed = await _loadSeed();
    final list = (seed['pbc_items'] as List<dynamic>? ?? const <dynamic>[])
        .map((e) => PbcItemModel.fromJson(e as Map<String, dynamic>))
        .toList();

    _memoryCache = list;
    await _persist(list);
    return list;
  }

  Future<List<PbcItemModel>> getByEngagementId(String engagementId) async {
    final list = await getAll();
    return list.where((x) => x.engagementId == engagementId).toList();
  }

  Future<PbcItemModel> upsert(PbcItemModel draft) async {
    final role = _session.current.role;
    Permissions.require(
      Permissions.canCreateEditDeletePbc(role),
      'Permission denied: Client users cannot create or edit PBC items.',
    );

    final list = [...await getAll()];

    final id = draft.id.trim().isEmpty ? _newId() : draft.id.trim();
    final normalized = draft.copyWith(
      id: id,
      updated: draft.updated.trim().isEmpty ? _todayIso() : draft.updated.trim(),
    );

    final idx = list.indexWhere((x) => x.id == id);
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
      Permissions.canCreateEditDeletePbc(role),
      'Permission denied: Client users cannot delete PBC items.',
    );

    final list = [...await getAll()];
    list.removeWhere((x) => x.id == id);

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

  Future<void> _persist(List<PbcItemModel> list) async {
    await store.prefs.setString(
      _cacheKey,
      jsonEncode(list.map((e) => e.toJson()).toList()),
    );
  }

  Future<Map<String, dynamic>> _loadSeed() async {
    final raw = await rootBundle.loadString('assets/seed/demo_data.json');
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  String _newId() => 'pbc-${DateTime.now().millisecondsSinceEpoch}';

  String _todayIso() {
    final d = DateTime.now();
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }
}