Future<void> ensureDir(String path) async {
  throw UnsupportedError('File features are disabled on web demo.');
}

Future<bool> fileExists(String path) async => false;

Future<String> readTextFile(String path) async {
  throw UnsupportedError('File features are disabled on web demo.');
}

Future<void> writeTextFile(String path, String contents) async {
  throw UnsupportedError('File features are disabled on web demo.');
}

Future<List<String>> readLines(String path) async => const <String>[];