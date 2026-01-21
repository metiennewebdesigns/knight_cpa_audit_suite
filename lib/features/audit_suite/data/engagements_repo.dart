import 'dart:convert';
import '../../../core/storage/local_store.dart';

class Engagement {
  Engagement({
    required this.id,
    required this.clientName,
    required this.entityType,
    required this.jurisdiction,
    required this.taxYears,
    required this.status,
    required this.updatedAt,
    required this.riskScore,
  });

  final String id;
  final String clientName;
  final String entityType;
  final String jurisdiction;
  final List<int> taxYears;
  final String status;
  final DateTime updatedAt;
  final int riskScore;

  Map<String, dynamic> toJson() => {
        'id': id,
        'clientName': clientName,
        'entityType': entityType,
        'jurisdiction': jurisdiction,
        'taxYears': taxYears,
        'status': status,
        'updatedAt': updatedAt.toIso8601String(),
        'riskScore': riskScore,
      };

  static Engagement fromJson(Map<String, dynamic> j) => Engagement(
        id: j['id'],
        clientName: j['clientName'],
        entityType: j['entityType'],
        jurisdiction: j['jurisdiction'],
        taxYears: List<int>.from(j['taxYears']),
        status: j['status'],
        updatedAt: DateTime.parse(j['updatedAt']),
        riskScore: j['riskScore'],
      );
}

class EngagementsRepo {
  EngagementsRepo(this.store);
  final LocalStore store;

  static const _key = 'engagements';

  Future<List<Engagement>> list() async {
    final raw = store.getString(_key);
    if (raw == null) return [];
    final data = jsonDecode(raw) as List;
    return data.map((e) => Engagement.fromJson(e)).toList();
  }

  Future<void> save(List<Engagement> items) async {
    await store.setString(
      _key,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }
}