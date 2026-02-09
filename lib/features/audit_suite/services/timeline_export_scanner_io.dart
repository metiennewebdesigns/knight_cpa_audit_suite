import 'dart:io' show Directory, File;

import 'package:path/path.dart' as p;

import '../../../core/utils/doc_path.dart';
import '../services/letter_exporter.dart';

class TimelineExportInfo {
  final int lettersGenerated;
  final String deliverableLastExportAt;
  final String packetLastExportAt;

  const TimelineExportInfo({
    required this.lettersGenerated,
    required this.deliverableLastExportAt,
    required this.packetLastExportAt,
  });
}

Future<TimelineExportInfo> scanTimelineExports(String engagementId) async {
  final docsPath = await getDocumentsPath();
  if (docsPath == null || docsPath.isEmpty) {
    return const TimelineExportInfo(lettersGenerated: 0, deliverableLastExportAt: '', packetLastExportAt: '');
  }

  final safeEngagementId = _safeId(engagementId);

  final lettersGenerated = await LetterExporter.getLettersGeneratedCount(
    docsPath: docsPath,
    engagementId: engagementId,
  );

  final deliverables = await _findLatestExport(
    folder: p.join(docsPath, 'Auditron', 'Deliverables'),
    prefix: 'Auditron_DeliverablePack_${safeEngagementId}_',
  );

  final packet = await _findLatestExport(
    folder: p.join(docsPath, 'Auditron', 'Packets'),
    prefix: 'Auditron_Packet_${safeEngagementId}_',
  );

  return TimelineExportInfo(
    lettersGenerated: lettersGenerated,
    deliverableLastExportAt: deliverables,
    packetLastExportAt: packet,
  );
}

String _safeId(String id) => id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');

Future<String> _findLatestExport({
  required String folder,
  required String prefix,
}) async {
  try {
    final dir = Directory(folder);
    if (!await dir.exists()) return '';

    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => p.basename(f.path).startsWith(prefix))
        .toList();

    if (files.isEmpty) return '';

    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files.first.lastModifiedSync().toIso8601String();
  } catch (_) {
    return '';
  }
}