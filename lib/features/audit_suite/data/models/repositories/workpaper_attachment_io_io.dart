import 'dart:io' show Directory, File;
import 'package:path/path.dart' as p;

abstract class WorkpaperAttachmentIO {
  static Future<String> copyInto({
    required String destDir,
    required String sourcePath,
    required String destFileName,
  }) async {
    final dir = Directory(destDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final destPath = p.join(dir.path, destFileName);
    await File(sourcePath).copy(destPath);
    return destPath;
  }

  static Future<void> deleteIfExists(String path) async {
    final f = File(path);
    if (await f.exists()) {
      await f.delete();
    }
  }
}