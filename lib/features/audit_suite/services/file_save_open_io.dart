// lib/features/audit_suite/services/file_save_open_io.dart
//
// IO implementation for save/open.

import 'dart:io';
import 'dart:typed_data';

import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'file_save_open.dart';

Future<PdfSaveResult> savePdfBytesAndMaybeOpenStandalone({
  required String fileName,
  required Uint8List bytes,
  String subfolder = 'auditron/exports',
  bool openAfterSave = true,
}) async {
  final docs = await getApplicationDocumentsDirectory();

  final safeSub = _sanitizeSubfolder(subfolder);
  final parts = <String>[
    docs.path,
    if (safeSub.isNotEmpty) ...safeSub.split('/'),
  ];

  final dirPath = p.joinAll(parts);
  final outDir = Directory(dirPath);
  if (!await outDir.exists()) {
    await outDir.create(recursive: true);
  }

  final safeName = _sanitizeFileName(fileName);
  final outPath = p.join(outDir.path, safeName);

  final f = File(outPath);
  await f.writeAsBytes(bytes, flush: true);

  bool didOpen = false;
  if (openAfterSave) {
    try {
      final r = await OpenFilex.open(outPath);
      didOpen = r.type == ResultType.done;
    } catch (_) {
      didOpen = false;
    }
  }

  return PdfSaveResult(
    savedPath: outPath,
    savedFileName: safeName,
    didOpenFile: didOpen,
  );
}

String _sanitizeSubfolder(String input) {
  final s = input.trim();
  if (s.isEmpty) return '';
  final normalized = s.replaceAll('\\', '/');
  final segments = normalized
      .split('/')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty && e != '.' && e != '..')
      .map((e) => e.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_'))
      .toList();
  return segments.join('/');
}

String _sanitizeFileName(String input) {
  var s = input.trim();
  if (s.isEmpty) s = 'export.pdf';

  s = s.replaceAll('\\', '/');
  if (s.contains('/')) s = s.split('/').last;

  s = s.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

  if (s.length > 180) {
    final ext = p.extension(s);
    final base = p.basenameWithoutExtension(s);
    s = base.substring(0, 180 - ext.length) + ext;
  }
  return s;
}