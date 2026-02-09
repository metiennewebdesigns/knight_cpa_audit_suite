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

/// Web-safe stub. Writes nothing; returns didOpenFile=false.
Future<SaveOpenResult> savePdfBytesAndMaybeOpen({
  required String fileName,
  required List<int> bytes,
  required String subfolder, // unused on web
}) async {
  return SaveOpenResult(
    savedPath: '',
    savedFileName: fileName,
    didOpenFile: false,
  );
}