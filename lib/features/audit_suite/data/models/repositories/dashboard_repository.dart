import 'dart:convert';

import 'package:flutter/services.dart';

import '../../../../../core/storage/local_store.dart';
import '../dashboard_models.dart';

class DashboardRepository {
  DashboardRepository(this.store);

  final LocalStore store;

  static const _cacheKey = 'demo_dashboard_counts_cache_v1';

  DashboardCounts? _memoryCache;

  Future<DashboardCounts> getCounts() async {
    // 1) In-memory cache
    if (_memoryCache != null) return _memoryCache!;

    // 2) SharedPreferences cache
    final cached = store.prefs.getString(_cacheKey);
    if (cached != null && cached.trim().isNotEmpty) {
      final decoded = jsonDecode(cached) as Map<String, dynamic>;
      _memoryCache = DashboardCounts.fromJson(decoded);
      return _memoryCache!;
    }

    // 3) Seed asset
    final seed = await _loadSeed();

    final clients = (seed['clients'] as List<dynamic>? ?? const <dynamic>[]);
    final engagements =
        (seed['engagements'] as List<dynamic>? ?? const <dynamic>[]);
    final workpapers =
        (seed['workpapers'] as List<dynamic>? ?? const <dynamic>[]);

    final counts = DashboardCounts(
      clientsCount: clients.length,
      engagementsCount: engagements.length,
      workpapersCount: workpapers.length,
    );

    _memoryCache = counts;

    await store.prefs.setString(_cacheKey, jsonEncode(counts.toJson()));

    return counts;
  }

  Future<void> clearCache() async {
    _memoryCache = null;
    await store.prefs.remove(_cacheKey);
  }

  Future<Map<String, dynamic>> _loadSeed() async {
    final raw = await rootBundle.loadString('assets/seed/demo_data.json');
    return jsonDecode(raw) as Map<String, dynamic>;
  }
}