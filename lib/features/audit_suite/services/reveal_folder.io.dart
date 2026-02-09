import 'dart:io' show Platform, Process;
import 'package:path/path.dart' as p;

import '../../../core/utils/doc_path.dart';

Future<void> revealFolder({required String subfolder}) async {
  final docsPath = await getDocumentsPath();
  if (docsPath == null || docsPath.isEmpty) {
    throw StateError('Documents directory not available.');
  }

  final folderPath = p.join(docsPath, subfolder);

  if (Platform.isMacOS) {
    await Process.run('open', [folderPath]);
  } else if (Platform.isWindows) {
    await Process.run('explorer', [folderPath]);
  } else if (Platform.isLinux) {
    await Process.run('xdg-open', [folderPath]);
  }
}