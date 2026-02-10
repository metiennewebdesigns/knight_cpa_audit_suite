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