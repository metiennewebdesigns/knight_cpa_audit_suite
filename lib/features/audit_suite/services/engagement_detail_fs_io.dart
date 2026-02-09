import 'dart:io' show Directory, File;

Future<void> ensureDir(String path) async {
  final dir = Directory(path);
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
}

Future<bool> fileExists(String path) async => File(path).exists();

Future<String> readTextFile(String path) async => File(path).readAsString();

Future<void> writeTextFile(String path, String contents) async {
  await File(path).writeAsString(contents, flush: true);
}

Future<List<String>> readLines(String path) async => File(path).readAsLines();