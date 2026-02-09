import 'dart:convert';
import 'dart:io' show Directory, File, FileMode;

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../../core/utils/doc_path.dart';

class EvidenceLedgerEntry {
  final String id;
  final String ts;
  final String engagementId;
  final String clientId;
  final String kind;
  final String logicalKey;
  final int version;
  final String fileName;
  final String filePath;
  final int bytes;
  final String sha256;
  final String note;
  final String sourcePath;

  const EvidenceLedgerEntry({
    required this.id,
    required this.ts,
    required this.engagementId,
    required this.clientId,
    required this.kind,
    required this.logicalKey,
    required this.version,
    required this.fileName,
    required this.filePath,
    required this.bytes,
    required this.sha256,
    required this.note,
    required this.sourcePath,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'ts': ts,
        'engagementId': engagementId,
        'clientId': clientId,
        'kind': kind,
        'logicalKey': logicalKey,
        'version': version,
        'fileName': fileName,
        'filePath': filePath,
        'bytes': bytes,
        'sha256': sha256,
        'note': note,
        'sourcePath': sourcePath,
      };

  static EvidenceLedgerEntry fromJson(Map<String, dynamic> j) {
    return EvidenceLedgerEntry(
      id: (j['id'] ?? '').toString(),
      ts: (j['ts'] ?? '').toString(),
      engagementId: (j['engagementId'] ?? '').toString(),
      clientId: (j['clientId'] ?? '').toString(),
      kind: (j['kind'] ?? '').toString(),
      logicalKey: (j['logicalKey'] ?? '').toString(),
      version: (j['version'] is int) ? (j['version'] as int) : int.tryParse('${j['version']}') ?? 0,
      fileName: (j['fileName'] ?? '').toString(),
      filePath: (j['filePath'] ?? '').toString(),
      bytes: (j['bytes'] is int) ? (j['bytes'] as int) : int.tryParse('${j['bytes']}') ?? 0,
      sha256: (j['sha256'] ?? '').toString(),
      note: (j['note'] ?? '').toString(),
      sourcePath: (j['sourcePath'] ?? '').toString(),
    );
  }
}

class EvidenceVerifyResult {
  final EvidenceLedgerEntry entry;
  final bool exists;
  final bool hashMatches;
  final String currentSha256;

  const EvidenceVerifyResult({
    required this.entry,
    required this.exists,
    required this.hashMatches,
    required this.currentSha256,
  });
}

class EvidenceLedger {
  static Future<Directory> _baseDir() async {
    final docsPath = await getDocumentsPath();
    if (docsPath == null || docsPath.isEmpty) {
      throw StateError('Documents directory not available.');
    }
    final dir = Directory(p.join(docsPath, 'Auditron'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<Directory> _ledgerDir() async {
    final base = await _baseDir();
    final dir = Directory(p.join(base.path, 'EvidenceLedger'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<Directory> _vaultDir(String engagementId) async {
    final base = await _baseDir();
    final dir = Directory(p.join(base.path, 'EvidenceVault', engagementId));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<File> _ledgerFile(String engagementId) async {
    final dir = await _ledgerDir();
    return File(p.join(dir.path, '$engagementId.jsonl'));
  }

  static Future<List<EvidenceLedgerEntry>> readAll(String engagementId) async {
    try {
      final f = await _ledgerFile(engagementId);
      if (!await f.exists()) return [];
      final lines = await f.readAsLines();
      return lines
          .where((l) => l.trim().isNotEmpty)
          .map((l) => EvidenceLedgerEntry.fromJson(jsonDecode(l) as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<String> sha256OfFile(String filePath) async {
    final file = File(filePath);
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  static int _nextVersion(List<EvidenceLedgerEntry> entries, String logicalKey) {
    final same = entries.where((e) => e.logicalKey == logicalKey).toList();
    if (same.isEmpty) return 1;
    same.sort((a, b) => b.version.compareTo(a.version));
    return same.first.version + 1;
  }

  static String _id() => 'ev_${DateTime.now().millisecondsSinceEpoch}';

  static Future<String?> importToVault({
    required String engagementId,
    required String sourcePath,
  }) async {
    try {
      final src = File(sourcePath);
      if (!await src.exists()) return null;

      final vault = await _vaultDir(engagementId);

      final ext = p.extension(sourcePath);
      final baseName = p.basenameWithoutExtension(sourcePath)
          .replaceAll(RegExp(r'[^a-zA-Z0-9 _.-]'), '')
          .trim();
      final safeBase = baseName.isEmpty ? 'evidence' : baseName;

      final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
      final fileName = '${safeBase}_$ts$ext';
      final destPath = p.join(vault.path, fileName);

      await src.copy(destPath);
      return destPath;
    } catch (_) {
      return null;
    }
  }

  static Future<EvidenceLedgerEntry?> recordFile({
    required String engagementId,
    required String clientId,
    required String kind,
    required String logicalKey,
    required String filePath,
    required String note,
    String sourcePath = '',
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      final bytes = await file.length();
      final hash = await sha256OfFile(filePath);

      final existing = await readAll(engagementId);
      final version = _nextVersion(existing, logicalKey);

      final entry = EvidenceLedgerEntry(
        id: _id(),
        ts: DateTime.now().toIso8601String(),
        engagementId: engagementId,
        clientId: clientId,
        kind: kind,
        logicalKey: logicalKey,
        version: version,
        fileName: p.basename(filePath),
        filePath: filePath,
        bytes: bytes,
        sha256: hash,
        note: note,
        sourcePath: sourcePath,
      );

      final ledger = await _ledgerFile(engagementId);
      await ledger.writeAsString(
        '${jsonEncode(entry.toJson())}\n',
        mode: FileMode.append,
        flush: true,
      );

      return entry;
    } catch (_) {
      return null;
    }
  }

  static Future<EvidenceLedgerEntry?> importAndRecord({
    required String engagementId,
    required String clientId,
    required String kind,
    required String logicalKey,
    required String sourcePath,
    required String note,
  }) async {
    final vaultPath = await importToVault(
      engagementId: engagementId,
      sourcePath: sourcePath,
    );
    if (vaultPath == null) return null;

    return recordFile(
      engagementId: engagementId,
      clientId: clientId,
      kind: kind,
      logicalKey: logicalKey,
      filePath: vaultPath,
      note: note,
      sourcePath: sourcePath,
    );
  }

  static Future<EvidenceVerifyResult> verifyEntry(EvidenceLedgerEntry e) async {
    try {
      final f = File(e.filePath);
      if (!await f.exists()) {
        return EvidenceVerifyResult(entry: e, exists: false, hashMatches: false, currentSha256: '');
      }
      final current = await sha256OfFile(e.filePath);
      return EvidenceVerifyResult(
        entry: e,
        exists: true,
        hashMatches: current == e.sha256,
        currentSha256: current,
      );
    } catch (_) {
      return EvidenceVerifyResult(entry: e, exists: false, hashMatches: false, currentSha256: '');
    }
  }

  /// ✅ NEW: verify all (newest first)
  static Future<List<EvidenceVerifyResult>> verifyAll(String engagementId) async {
    final entries = await readAll(engagementId);
    final out = <EvidenceVerifyResult>[];
    for (final e in entries.reversed) {
      out.add(await verifyEntry(e));
    }
    return out;
  }
}