abstract class WorkpaperAttachmentIO {
  static Future<String> copyInto({
    required String destDir,
    required String sourcePath,
    required String destFileName,
  }) {
    throw UnsupportedError('Attachments are not supported in the web demo');
  }

  static Future<void> deleteIfExists(String path) async {
    // no-op
  }
}