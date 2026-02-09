// Web stub – NO dart:io imports here.
Future<bool> fileExists(String path) async => false;

Future<void> ensureDir(String dirPath) async {
  throw UnsupportedError('File system not supported on web');
}

Future<String> readTextFile(String path) async {
  throw UnsupportedError('File system not supported on web');
}

Future<void> writeTextFile(String path, String text) async {
  throw UnsupportedError('File system not supported on web');
}

Future<List<String>> readLines(String path) async {
  throw UnsupportedError('File system not supported on web');
}

Future<List<String>> listFiles(String folderPath) async => const <String>[];

Future<String> modifiedIso(String filePath) async => '';