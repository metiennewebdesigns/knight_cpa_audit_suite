import 'dart:convert';

import '../../../../../core/storage/local_store.dart';
import '../discrepancy_model.dart';

class DiscrepancySummary {
  final int openCount;
  final double openTotal;

  const DiscrepancySummary({
    required this.openCount,
    required this.openTotal,
  });
}

class DiscrepanciesRepository {
  DiscrepanciesRepository(this.store);

  final LocalStore store;

  String _key(String engagementId) => 'auditron_discrepancies_${engagementId}_v1';

  /// ✅ Matches your screen: _repo.list(engagementId)
  Future<List<DiscrepancyModel>> list(String engagementId) async {
    final raw = store.prefs.getString(_key(engagementId));
    if (raw == null || raw.trim().isEmpty) return const <DiscrepancyModel>[];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => DiscrepancyModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const <DiscrepancyModel>[];
    }
  }

  Future<void> _saveAll(String engagementId, List<DiscrepancyModel> items) async {
    await store.prefs.setString(
      _key(engagementId),
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }

  /// ✅ Matches your screen: _repo.upsert(d)
  Future<DiscrepancyModel> upsert(DiscrepancyModel d) async {
    final items = [...await list(d.engagementId)];
    final idx = items.indexWhere((x) => x.id == d.id);

    if (idx >= 0) {
      items[idx] = d;
    } else {
      items.add(d);
    }

    await _saveAll(d.engagementId, items);
    return d;
  }

  Future<void> remove(String engagementId, String id) async {
    final items = [...await list(engagementId)];
    items.removeWhere((x) => x.id == id);
    await _saveAll(engagementId, items);
  }

  /// ✅ Used by engagement_detail.dart
  Future<DiscrepancySummary> summary(String engagementId) async {
    final items = await list(engagementId);
    final open = items.where((d) => d.isOpen).toList();
    final total = open.fold<double>(0.0, (sum, d) => sum + (d.amount.isNaN ? 0.0 : d.amount));
    return DiscrepancySummary(openCount: open.length, openTotal: total);
  }
}