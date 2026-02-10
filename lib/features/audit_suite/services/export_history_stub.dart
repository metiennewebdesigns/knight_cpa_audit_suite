// lib/features/audit_suite/services/export_history_stub.dart
//
// Web-safe stub (no dart:io).
// Keeps API compatible with your screens/widgets.

import '../../../core/storage/local_store.dart';

class ExportHistoryEntry {
  final String type;
  final String title;
  final String path;
  final String? engagementId;
  final DateTime createdAt;

  const ExportHistoryEntry({
    required this.type,
    required this.title,
    required this.path,
    required this.createdAt,
    this.engagementId,
  });

  String get createdAtIso => createdAt.toIso8601String();

  Map<String, dynamic> toJson() => {
        'type': type,
        'title': title,
        'path': path,
        'engagementId': engagementId,
        'createdAt': createdAtIso,
      };

  static ExportHistoryEntry fromJson(Map<String, dynamic> j) {
    return ExportHistoryEntry(
      type: (j['type'] ?? '').toString(),
      title: (j['title'] ?? '').toString(),
      path: (j['path'] ?? '').toString(),
      engagementId: j['engagementId'] == null ? null : j['engagementId'].toString(),
      createdAt: DateTime.tryParse((j['createdAt'] ?? '').toString()) ?? DateTime.now(),
    );
  }
}

class ExportHistoryVm {
  final List<ExportHistoryEntry> entries;
  const ExportHistoryVm({required this.entries});

  static const empty = ExportHistoryVm(entries: []);

  int get count => entries.length;

  // Match legacy computed getters used by UI
  int get deliverablePackCount => 0;
  int get auditPacketCount => 0;
  int get integrityCertCount => 0;
  int get portalAuditCount => 0;
  int get lettersCount => 0;

  String get deliverableLastIso => '';
  String get packetLastIso => '';
  String get certLastIso => '';
  String get portalAuditLastIso => '';
  String get lettersLastIso => '';
}

class ExportHistoryReader {
  static Future<ExportHistoryVm> load(LocalStore store, String engagementId) async {
    // Web stub: empty history
    return ExportHistoryVm.empty;
  }
}

class ExportHistoryWriter {
  static Future<void> add({
    required LocalStore store,
    required String engagementId,
    required ExportHistoryEntry entry,
  }) async {
    // Web stub: no-op
  }

  static Future<void> clear({
    required LocalStore store,
    required String engagementId,
  }) async {
    // Web stub: no-op
  }
}