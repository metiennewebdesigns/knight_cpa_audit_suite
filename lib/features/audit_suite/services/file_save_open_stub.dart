// lib/features/audit_suite/services/file_save_open_stub.dart

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
  required String subfolder,
}) async {
  throw UnsupportedError('File export is disabled on web demo.');
}