// lib/features/audit_suite/services/evidence_ledger_stub.dart
//
// Web implementation: filesystem-based vault/ledger is disabled.
// This prevents MissingPluginException + dart:io compile failures.

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
  static Future<List<EvidenceLedgerEntry>> readAll(String engagementId) async => const [];

  static Future<String> sha256OfFile(String filePath) async {
    throw UnsupportedError('Evidence ledger is disabled on web.');
  }

  static Future<String?> importToVault({
    required String engagementId,
    required String sourcePath,
  }) async {
    return null;
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
    return null;
  }

  static Future<EvidenceLedgerEntry?> importAndRecord({
    required String engagementId,
    required String clientId,
    required String kind,
    required String logicalKey,
    required String sourcePath,
    required String note,
  }) async {
    return null;
  }

  static Future<EvidenceVerifyResult> verifyEntry(EvidenceLedgerEntry e) async {
    return EvidenceVerifyResult(entry: e, exists: false, hashMatches: false, currentSha256: '');
  }

  static Future<List<EvidenceVerifyResult>> verifyAll(String engagementId) async => const [];
}