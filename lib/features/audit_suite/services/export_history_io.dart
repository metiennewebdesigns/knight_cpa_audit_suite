import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/storage/local_store.dart';

class ExportHistoryVm {
  final int deliverablePackCount;
  final String deliverableLastIso;

  final int auditPacketCount;
  final String packetLastIso;

  final int integrityCertCount;
  final String certLastIso;

  final int portalAuditCount;
  final String portalAuditLastIso;

  final int lettersCount;
  final String lettersLastIso;

  const ExportHistoryVm({
    required this.deliverablePackCount,
    required this.deliverableLastIso,
    required this.auditPacketCount,
    required this.packetLastIso,
    required this.integrityCertCount,
    required this.certLastIso,
    required this.portalAuditCount,
    required this.portalAuditLastIso,
    required this.lettersCount,
    required this.lettersLastIso,
  });

  static const empty = ExportHistoryVm(
    deliverablePackCount: 0,
    deliverableLastIso: '',
    auditPacketCount: 0,
    packetLastIso: '',
    integrityCertCount: 0,
    certLastIso: '',
    portalAuditCount: 0,
    portalAuditLastIso: '',
    lettersCount: 0,
    lettersLastIso: '',
  );
}

class ExportHistoryReader {
  static Future<ExportHistoryVm> load(LocalStore store, String engagementId) async {
    if (!store.canUseFileSystem || (store.documentsPath ?? '').trim().isEmpty) {
      return ExportHistoryVm.empty;
    }

    final docsPath = store.documentsPath!.trim();
    final safe = _safeId(engagementId).toLowerCase();

    final deliverables = await _countAndLatestInFolder(
      folder: p.join(docsPath, 'Auditron', 'Deliverables'),
      containsLower: '_${safe}_',
      endsWithLower: '.pdf',
    );

    final packets = await _countAndLatestInFolder(
      folder: p.join(docsPath, 'Auditron', 'Packets'),
      containsLower: '_${safe}_',
      endsWithLower: '.pdf',
    );

    final certs = await _countAndLatestInFolder(
      folder: p.join(docsPath, 'Auditron', 'Certificates'),
      containsLower: safe,
      endsWithLower: '.pdf',
    );

    final audits = await _countAndLatestInFolder(
      folder: p.join(docsPath, 'Auditron', 'AuditTrail'),
      containsLower: safe,
      endsWithLower: '.pdf',
    );

    final letters = await _lettersMetaCountAndLatest(docsPath, engagementId);

    return ExportHistoryVm(
      deliverablePackCount: deliverables.count,
      deliverableLastIso: deliverables.latestIso,
      auditPacketCount: packets.count,
      packetLastIso: packets.latestIso,
      integrityCertCount: certs.count,
      certLastIso: certs.latestIso,
      portalAuditCount: audits.count,
      portalAuditLastIso: audits.latestIso,
      lettersCount: letters.count,
      lettersLastIso: letters.latestIso,
    );
  }

  static String _safeId(String id) => id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');

  static Future<_CountLatest> _countAndLatestInFolder({
    required String folder,
    required String containsLower,
    required String endsWithLower,
  }) async {
    try {
      final dir = Directory(folder);
      if (!await dir.exists()) return const _CountLatest(count: 0, latestIso: '');

      final files = dir
          .listSync(recursive: false, followLinks: false)
          .whereType<File>()
          .map((f) => f.path)
          .toList();

      final matches = files.where((fp) {
        final name = p.basename(fp).toLowerCase();
        return name.contains(containsLower) && name.endsWith(endsWithLower);
      }).toList();

      if (matches.isEmpty) return const _CountLatest(count: 0, latestIso: '');

      String latestIso = '';
      for (final fp in matches) {
        final iso = await _modifiedIso(fp);
        if (iso.compareTo(latestIso) > 0) latestIso = iso;
      }

      return _CountLatest(count: matches.length, latestIso: latestIso);
    } catch (_) {
      return const _CountLatest(count: 0, latestIso: '');
    }
  }

  static Future<String> _modifiedIso(String filePath) async {
    try {
      final stat = await FileStat.stat(filePath);
      return stat.modified.toIso8601String();
    } catch (_) {
      return '';
    }
  }

  static Future<_CountLatest> _lettersMetaCountAndLatest(String docsPath, String engagementId) async {
    try {
      final metaFile = p.join(docsPath, 'Auditron', 'Letters', '_meta', '$engagementId.json');
      final f = File(metaFile);
      if (!await f.exists()) return const _CountLatest(count: 0, latestIso: '');

      final raw = await f.readAsString();
      if (raw.trim().isEmpty) return const _CountLatest(count: 0, latestIso: '');

      final data = jsonDecode(raw) as Map<String, dynamic>;
      final exports = (data['exports'] as List<dynamic>?) ?? <dynamic>[];

      int count = 0;
      String latest = '';
      for (final e in exports) {
        if (e is! Map) continue;
        count++;
        final at = (e['createdAt'] ?? '').toString();
        if (at.compareTo(latest) > 0) latest = at;
      }

      return _CountLatest(count: count, latestIso: latest);
    } catch (_) {
      return const _CountLatest(count: 0, latestIso: '');
    }
  }
}

class _CountLatest {
  final int count;
  final String latestIso;
  const _CountLatest({required this.count, required this.latestIso});
}
