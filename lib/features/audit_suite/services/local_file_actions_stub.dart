Future<bool> localFileExists(String path) async => false;

Future<void> openLocalFile(String path) async {
  throw UnsupportedError('Opening local files is disabled on web demo.');
}