import 'dart:io';

import 'package:path/path.dart' as p;

Future<bool> fileExists(String path) async {
  try {
    return File(path).exists();
  } catch (_) {
    return false;
  }
}

Future<void> ensureDir(String dirPath) async {
  final dir = Directory(dirPath);
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
}

Future<String> readTextFile(String path) async {
  return File(path).readAsString();
}

Future<void> writeTextFile(String path, String text) async {
  final f = File(path);
  await f.writeAsString(text, flush: true);
}

Future<List<String>> readLines(String path) async {
  return File(path).readAsLines();
}

/// Returns absolute file paths (non-recursive) in folderPath
Future<List<String>> listFiles(String folderPath) async {
  try {
    final dir = Directory(folderPath);
    if (!await dir.exists()) return const <String>[];

    final out = <String>[];
    final ents = dir.listSync(recursive: false);
    for (final e in ents) {
      if (e is File) out.add(e.path);
    }
    return out;
  } catch (_) {
    return const <String>[];
  }
}

Future<String> modifiedIso(String filePath) async {
  try {
    final dt = await File(filePath).lastModified();
    return dt.toIso8601String();
  } catch (_) {
    return '';
  }
}

// Utility used by other code sometimes
String joinPath(String a, String b) => p.join(a, b);