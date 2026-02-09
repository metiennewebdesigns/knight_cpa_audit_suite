import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../../core/storage/local_store.dart';
import '../services/engagement_detail_fs.dart';

class AiPriorityHistoryEntry {
  final String atIso;
  final String label;
  final int score;
  final String reason;

  const AiPriorityHistoryEntry({
    required this.atIso,
    required this.label,
    required this.score,
    required this.reason,
  });

  Map<String, dynamic> toJson() => {
        'atIso': atIso,
        'label': label,
        'score': score,
        'reason': reason,
      };

  static AiPriorityHistoryEntry? fromJson(dynamic j) {
    if (j is! Map) return null;
    final atIso = (j['atIso'] ?? '').toString();
    final label = (j['label'] ?? '').toString();
    final reason = (j['reason'] ?? '').toString();
    final scoreRaw = j['score'];
    final score = (scoreRaw is int) ? scoreRaw : int.tryParse('$scoreRaw') ?? 0;
    if (label.trim().isEmpty) return null;
    return AiPriorityHistoryEntry(
      atIso: atIso,
      label: label,
      score: score,
      reason: reason,
    );
  }
}

class AiPriorityHistoryStore {
  static String _metaDirPath(String docsPath) => p.join(docsPath, 'Auditron', 'EngagementMeta');
  static String _metaFilePath(String docsPath, String engagementId) => p.join(_metaDirPath(docsPath), '$engagementId.json');

  static Future<List<AiPriorityHistoryEntry>> read(LocalStore store, String engagementId) async {
    if (kIsWeb || !store.canUseFileSystem || (store.documentsPath ?? '').isEmpty) return const [];
    final docsPath = store.documentsPath!;
    final fp = _metaFilePath(docsPath, engagementId);

    try {
      if (!await fileExists(fp)) return const [];
      final raw = await readTextFile(fp);
      if (raw.trim().isEmpty) return const [];
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final list = (data['aiPriorityHistory'] as List<dynamic>? ?? const []);
      final out = <AiPriorityHistoryEntry>[];
      for (final it in list) {
        final e = AiPriorityHistoryEntry.fromJson(it);
        if (e != null) out.add(e);
      }
      out.sort((a, b) => b.atIso.compareTo(a.atIso));
      return out;
    } catch (_) {
      return const [];
    }
  }

  static Future<void> append(
    LocalStore store, {
    required String engagementId,
    required String label,
    required int score,
    required String reason,
  }) async {
    if (kIsWeb || !store.canUseFileSystem || (store.documentsPath ?? '').isEmpty) return;

    final docsPath = store.documentsPath!;
    await ensureDir(_metaDirPath(docsPath));

    final fp = _metaFilePath(docsPath, engagementId);

    Map<String, dynamic> data = {};
    try {
      if (await fileExists(fp)) {
        final raw = await readTextFile(fp);
        if (raw.trim().isNotEmpty) data = jsonDecode(raw) as Map<String, dynamic>;
      }
    } catch (_) {
      data = {};
    }

    final List<dynamic> list = (data['aiPriorityHistory'] as List<dynamic>?) ?? <dynamic>[];
    list.add(
      AiPriorityHistoryEntry(
        atIso: DateTime.now().toIso8601String(),
        label: label,
        score: score,
        reason: reason,
      ).toJson(),
    );

    // keep last 30
    if (list.length > 30) {
      final start = list.length - 30;
      data['aiPriorityHistory'] = list.sublist(start);
    } else {
      data['aiPriorityHistory'] = list;
    }

    try {
      await writeTextFile(fp, jsonEncode(data));
    } catch (_) {}
  }
}