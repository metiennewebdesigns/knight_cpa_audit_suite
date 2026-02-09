import 'dart:convert';
import 'package:flutter/services.dart';

import '../../../../../core/storage/local_store.dart';
import '../client_models.dart';
import '../permissions.dart';
import '../repositories/session_repository.dart';

class ClientsRepository {
  ClientsRepository(this.store);

  final LocalStore store;

  static const _cacheKey = 'demo_clients_cache_v1';
  List<ClientModel>? _memoryCache;

  SessionRepository get _session => SessionRepository(store);

  Future<List<ClientModel>> getClients() async {
    if (_memoryCache != null) return _memoryCache!;

    final cached = store.prefs.getString(_cacheKey);
    if (cached != null && cached.trim().isNotEmpty) {
      final decoded = jsonDecode(cached) as List<dynamic>;
      _memoryCache = decoded.map((e) => ClientModel.fromJson(e as Map<String, dynamic>)).toList();
      return _memoryCache!;
    }

    final seed = await _loadSeed();
    final list = (seed['clients'] as List<dynamic>? ?? const <dynamic>[])
        .map((e) => ClientModel.fromJson(e as Map<String, dynamic>))
        .toList();

    _memoryCache = list;
    await _persist(list);
    return list;
  }

  Future<ClientModel?> getById(String id) async {
    final list = await getClients();
    try {
      return list.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<ClientModel> upsert(ClientModel draft) async {
    final role = _session.current.role;
    Permissions.require(
      Permissions.canManageClients(role),
      'Permission denied: Client users cannot create or edit clients.',
    );

    final list = [...await getClients()];

    final id = draft.id.trim().isEmpty ? _newId() : draft.id.trim();
    final normalized = draft.copyWith(
      id: id,
      updated: draft.updated.trim().isEmpty ? _todayIso() : draft.updated.trim(),
    );

    final idx = list.indexWhere((c) => c.id == id);
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
      Permissions.canManageClients(role),
      'Permission denied: Client users cannot delete clients.',
    );

    final list = [...await getClients()];
    list.removeWhere((c) => c.id == id);

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

  Future<void> _persist(List<ClientModel> list) async {
    await store.prefs.setString(
      _cacheKey,
      jsonEncode(list.map((e) => e.toJson()).toList()),
    );
  }

  Future<Map<String, dynamic>> _loadSeed() async {
    final raw = await rootBundle.loadString('assets/seed/demo_data.json');
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  String _newId() => 'cli-${DateTime.now().millisecondsSinceEpoch}';

  String _todayIso() {
    final d = DateTime.now();
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }
}