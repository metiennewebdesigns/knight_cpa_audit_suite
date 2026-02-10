// lib/features/audit_suite/services/export_history_io.dart
//
// IO-only export history persistence.
// Restores legacy API used across screens/widgets:
// - ExportHistoryVm + computed getters (counts/last dates)
// - ExportHistoryReader.load(LocalStore store, String engagementId)

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/storage/local_store.dart';

class ExportHistoryEntry {
  final String type; // e.g. "PBC PDF", "Audit Packet", "Integrity Certificate"
  final String title; // friendly label
  final String path; // saved file path
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

  // --------- Legacy computed getters expected by your UI ---------

  int get deliverablePackCount => _countWhere(_isDeliverablePack);
  int get auditPacketCount => _countWhere(_isAuditPacket);
  int get integrityCertCount => _countWhere(_isIntegrityCert);
  int get portalAuditCount => _countWhere(_isPortalAuditTrail);
  int get lettersCount => _countWhere(_isLetter);

  String get deliverableLastIso => _lastIsoWhere(_isDeliverablePack);
  String get packetLastIso => _lastIsoWhere(_isAuditPacket);
  String get certLastIso => _lastIsoWhere(_isIntegrityCert);
  String get portalAuditLastIso => _lastIsoWhere(_isPortalAuditTrail);
  String get lettersLastIso => _lastIsoWhere(_isLetter);

  // --------- internals ---------

  int _countWhere(bool Function(ExportHistoryEntry e) test) {
    var n = 0;
    for (final e in entries) {
      if (test(e)) n++;
    }
    return n;
  }

  String _lastIsoWhere(bool Function(ExportHistoryEntry e) test) {
    DateTime? best;
    for (final e in entries) {
      if (!test(e)) continue;
      if (best == null || e.createdAt.isAfter(best)) best = e.createdAt;
    }
    return best?.toIso8601String() ?? '';
  }

  String _hay(ExportHistoryEntry e) => '${e.type} ${e.title}'.toLowerCase();

  bool _isDeliverablePack(ExportHistoryEntry e) {
    final h = _hay(e);
    // “Deliverable Pack”, “Deliverables”, “Deliverable package”
    return h.contains('deliverable') && (h.contains('pack') || h.contains('package') || h.contains('bundle'));
  }

  bool _isAuditPacket(ExportHistoryEntry e) {
    final h = _hay(e);
    // “Audit Packet”, “Packet”
    return h.contains('audit packet') || (h.contains('packet') && h.contains('audit'));
  }

  bool _isIntegrityCert(ExportHistoryEntry e) {
    final h = _hay(e);
    // “Integrity Certificate”, “Cert”
    return h.contains('integrity') && (h.contains('cert') || h.contains('certificate'));
  }

  bool _isPortalAuditTrail(ExportHistoryEntry e) {
    final h = _hay(e);
    // “Portal Audit”, “Portal Trail”, “Client Portal Audit Trail”
    final hasPortal = h.contains('portal');
    final hasAudit = h.contains('audit') || h.contains('trail') || h.contains('log');
    return hasPortal && hasAudit;
  }

  bool _isLetter(ExportHistoryEntry e) {
    final h = _hay(e);
    // “Letter”, “Engagement letter”, etc.
    return h.contains('letter');
  }
}

class ExportHistoryReader {
  static const int _maxEntries = 200;

  static Future<ExportHistoryVm> load(LocalStore store, String engagementId) async {
    // store currently unused; signature preserved for compatibility
    final file = await _historyFileForEngagement(engagementId);
    if (!await file.exists()) return ExportHistoryVm.empty;

    try {
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! List) return ExportHistoryVm.empty;

      final entries = <ExportHistoryEntry>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          entries.add(ExportHistoryEntry.fromJson(item));
        } else if (item is Map) {
          entries.add(ExportHistoryEntry.fromJson(item.cast<String, dynamic>()));
        }
        if (entries.length >= _maxEntries) break;
      }

      return ExportHistoryVm(entries: entries);
    } catch (_) {
      return ExportHistoryVm.empty;
    }
  }

  static Future<File> _historyFileForEngagement(String engagementId) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'auditron', 'export_history'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final safe = _safeFileChunk(engagementId);
    return File(p.join(dir.path, 'exports_$safe.json'));
  }

  static String _safeFileChunk(String input) {
    final s = input.trim();
    if (s.isEmpty) return 'engagement';
    final cleaned = s.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return cleaned.length > 60 ? cleaned.substring(0, 60) : cleaned;
  }
}

class ExportHistoryWriter {
  static const int _maxEntries = 200;

  static Future<void> add({
    required LocalStore store,
    required String engagementId,
    required ExportHistoryEntry entry,
  }) async {
    final file = await ExportHistoryReader._historyFileForEngagement(engagementId);

    final current = await ExportHistoryReader.load(store, engagementId);
    final next = <ExportHistoryEntry>[entry, ...current.entries];

    // Dedup lightly by (type|path|createdAt)
    final seen = <String>{};
    final deduped = <ExportHistoryEntry>[];
    for (final e in next) {
      final k = '${e.type}|${e.path}|${e.createdAtIso}';
      if (seen.add(k)) deduped.add(e);
      if (deduped.length >= _maxEntries) break;
    }

    final raw = const JsonEncoder.withIndent('  ')
        .convert(deduped.map((e) => e.toJson()).toList(growable: false));

    await file.writeAsString(raw, flush: true);
  }

  static Future<void> clear({
    required LocalStore store,
    required String engagementId,
  }) async {
    final file = await ExportHistoryReader._historyFileForEngagement(engagementId);
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (_) {}
    }
  }
}