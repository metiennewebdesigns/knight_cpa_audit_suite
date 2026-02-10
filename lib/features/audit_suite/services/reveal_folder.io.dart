// lib/features/audit_suite/services/reveal_folder_io.dart
//
// IO implementation: opens Documents/<subfolder> in the OS file manager.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<void> revealFolder({
  required String subfolder,
}) async {
  final docs = await getApplicationDocumentsDirectory();

  final safe = _sanitizeSubfolder(subfolder);
  final folderPath = safe.isEmpty ? docs.path : p.joinAll([docs.path, ...safe.split('/')]);

  final dir = Directory(folderPath);
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }

  if (Platform.isMacOS) {
    await Process.run('open', [dir.path]);
    return;
  }
  if (Platform.isWindows) {
    await Process.run('explorer', [dir.path]);
    return;
  }
  // Linux and others
  await Process.run('xdg-open', [dir.path]);
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