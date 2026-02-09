// lib/features/audit_suite/services/client_portal_fs_io.dart

import 'dart:convert';
import 'dart:io' show Directory, File, FileMode;
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../../core/utils/doc_path.dart';

class VaultSaveResult {
  final String fileName;
  final String filePath;
  final int bytes;
  final String sha256;

  const VaultSaveResult({
    required this.fileName,
    required this.filePath,
    required this.bytes,
    required this.sha256,
  });
}

class ClientPortalFs {
  static Future<String> _docsPath() async {
    final dp = await getDocumentsPath();
    if (dp == null || dp.isEmpty) throw StateError('Documents directory not available.');
    return dp;
  }

  static Future<Map<String, dynamic>> readEngagementMeta(String engagementId) async {
    try {
      final docs = await _docsPath();
      final f = File(p.join(docs, 'Auditron', 'EngagementMeta', '$engagementId.json'));
      if (!await f.exists()) return {};
      final raw = await f.readAsString();
      if (raw.trim().isEmpty) return {};
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  static Future<List<Map<String, dynamic>>> readPortalLogEvents(String engagementId, {int limit = 200}) async {
    try {
      final docs = await _docsPath();
      final f = File(p.join(docs, 'Auditron', 'ClientPortalLogs', '$engagementId.jsonl'));
      if (!await f.exists()) return [];

      final lines = await f.readAsLines();
      final out = <Map<String, dynamic>>[];
      for (final line in lines.reversed) {
        final s = line.trim();
        if (s.isEmpty) continue;
        try {
          out.add(jsonDecode(s) as Map<String, dynamic>);
        } catch (_) {}
        if (out.length >= limit) break;
      }
      return out.reversed.toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> logPortalEvent({
    required String engagementId,
    required String kind,
    required String note,
    Map<String, dynamic>? extra,
  }) async {
    try {
      final docs = await _docsPath();
      final dir = Directory(p.join(docs, 'Auditron', 'ClientPortalLogs'));
      if (!await dir.exists()) await dir.create(recursive: true);

      final f = File(p.join(dir.path, '$engagementId.jsonl'));
      final obj = <String, dynamic>{
        'createdAt': DateTime.now().toIso8601String(),
        'engagementId': engagementId,
        'kind': kind,
        'note': note,
        ...?extra,
      };

      await f.writeAsString('${jsonEncode(obj)}\n', mode: FileMode.append, flush: true);
    } catch (_) {}
  }

  static Future<List<Map<String, dynamic>>> readPbcItemsRaw(String engagementId) async {
    try {
      final docs = await _docsPath();
      final f = File(p.join(docs, 'Auditron', 'PBC', '$engagementId.json'));
      if (!await f.exists()) return const [];
      final raw = await f.readAsString();
      if (raw.trim().isEmpty) return const [];
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final items = (data['items'] as List<dynamic>? ?? const <dynamic>[]);
      return items.whereType<Map>().map((m) => Map<String, dynamic>.from(m as Map)).toList();
    } catch (_) {
      return const [];
    }
  }

  static String _fallbackKey(String title) =>
      title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');

  static Future<void> markPbcItemReceived(String engagementId, String itemId) async {
    try {
      final docs = await _docsPath();
      final f = File(p.join(docs, 'Auditron', 'PBC', '$engagementId.json'));
      if (!await f.exists()) return;

      final raw = await f.readAsString();
      if (raw.trim().isEmpty) return;

      final data = jsonDecode(raw) as Map<String, dynamic>;
      final items = (data['items'] as List<dynamic>? ?? <dynamic>[]);

      bool changed = false;
      for (final it in items) {
        if (it is! Map) continue;

        final id = (it['id'] ?? '').toString().trim();
        final title = (it['title'] ?? it['name'] ?? '').toString().trim();
        final matchId = id.isNotEmpty ? id == itemId : _fallbackKey(title) == itemId;

        if (!matchId) continue;

        final status = (it['status'] ?? '').toString().toLowerCase();
        if (status == 'reviewed') return;

        it['status'] = 'received';
        it['receivedAt'] = DateTime.now().toIso8601String();
        changed = true;
      }

      if (changed) {
        data['items'] = items;
        await f.writeAsString(jsonEncode(data), flush: true);
      }
    } catch (_) {}
  }

  static String _uuidLike() {
    final r = Random.secure();
    final a = r.nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
    final b = r.nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
    final c = r.nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
    final d = r.nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
    return '$a$b-$c$d';
  }

  static Future<void> _appendEvidenceLedgerJsonLine({
    required String engagementId,
    required String jsonLine,
  }) async {
    final docs = await _docsPath();
    final dir = Directory(p.join(docs, 'Auditron', 'EvidenceLedger'));
    if (!await dir.exists()) await dir.create(recursive: true);

    final f = File(p.join(dir.path, '$engagementId.jsonl'));
    await f.writeAsString('$jsonLine\n', mode: FileMode.append, flush: true);
  }

  static Future<VaultSaveResult> saveToVaultAndLedger({
    required String engagementId,
    required String sourcePath,
    required String originalName,
    required String pbcItemId,
    required String pbcItemTitle,
  }) async {
    final docs = await _docsPath();

    final vaultDir = Directory(p.join(docs, 'Auditron', 'EvidenceVault', engagementId));
    if (!await vaultDir.exists()) {
      await vaultDir.create(recursive: true);
    }

    final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
    final safeName = originalName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final outName = '${p.basenameWithoutExtension(safeName)}_$ts${p.extension(safeName)}';
    final outPath = p.join(vaultDir.path, outName);

    final src = File(sourcePath);
    final bytes = await src.readAsBytes();
    final sha = sha256.convert(bytes).toString();

    await File(outPath).writeAsBytes(bytes, flush: true);

    await _appendEvidenceLedgerJsonLine(
      engagementId: engagementId,
      jsonLine: jsonEncode({
        'id': _uuidLike(),
        'ts': DateTime.now().toIso8601String(),
        'engagementId': engagementId,
        'clientId': '',
        'kind': 'client_portal_upload',
        'logicalKey': 'pbc:$pbcItemId:$outName',
        'version': 1,
        'fileName': outName,
        'filePath': outPath,
        'bytes': bytes.length,
        'sha256': sha,
        'note': safeName,
        'pbcItemId': pbcItemId,
        'pbcItemTitle': pbcItemTitle,
      }),
    );

    return VaultSaveResult(
      fileName: outName,
      filePath: outPath,
      bytes: bytes.length,
      sha256: sha,
    );
  }
}