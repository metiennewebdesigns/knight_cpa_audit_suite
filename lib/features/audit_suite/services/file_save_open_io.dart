import 'dart:io';

import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class SavedFileResult {
  final String savedPath;
  final String savedFileName;
  final bool didOpenFile;

  const SavedFileResult({
    required this.savedPath,
    required this.savedFileName,
    required this.didOpenFile,
  });
}

/// Backwards-compatible alias type (older code expects SaveOpenResult).
class SaveOpenResult extends SavedFileResult {
  const SaveOpenResult({
    required super.savedPath,
    required super.savedFileName,
    required super.didOpenFile,
  });
}

Future<SaveOpenResult> savePdfBytesAndMaybeOpen({
  required String fileName,
  required List<int> bytes,
  required String subfolder,
}) async {
  final docs = await getApplicationDocumentsDirectory();

  // subfolder like "Auditron/Letters"
  final parts = subfolder.split('/').where((s) => s.trim().isNotEmpty).toList();
  final folder = Directory(p.joinAll([docs.path, ...parts]));

  if (!await folder.exists()) {
    await folder.create(recursive: true);
  }

  final outPath = p.join(folder.path, fileName);
  final f = File(outPath);
  await f.writeAsBytes(bytes, flush: true);

  bool opened = false;
  try {
    final res = await OpenFilex.open(outPath);
    opened = (res.type == ResultType.done);
  } catch (_) {
    opened = false;
  }

  return SaveOpenResult(
    savedPath: outPath,
    savedFileName: fileName,
    didOpenFile: opened,
  );
}