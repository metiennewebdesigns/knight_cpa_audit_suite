// lib/features/audit_suite/services/file_save_open_io.dart

import 'dart:io' show Directory, File;

import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;

import '../../../core/utils/doc_path.dart';

class SaveOpenResult {
  final String savedPath;
  final String savedFileName;
  final bool didOpenFile;

  const SaveOpenResult({
    required this.savedPath,
    required this.savedFileName,
    required this.didOpenFile,
  });
}

Future<SaveOpenResult> savePdfBytesAndMaybeOpen({
  required String fileName,
  required List<int> bytes,
  required String subfolder, // e.g. "Auditron/Packets"
}) async {
  final docsPath = await getDocumentsPath();
  if (docsPath == null || docsPath.isEmpty) {
    throw StateError('Documents directory not available.');
  }

  final folder = Directory(p.join(docsPath, subfolder));
  if (!await folder.exists()) {
    await folder.create(recursive: true);
  }

  final outPath = p.join(folder.path, fileName);
  await File(outPath).writeAsBytes(bytes, flush: true);

  bool opened = false;
  try {
    final res = await OpenFilex.open(outPath);
    opened = (res.type == ResultType.done);
  } catch (_) {}

  return SaveOpenResult(
    savedPath: outPath,
    savedFileName: fileName,
    didOpenFile: opened,
  );
}