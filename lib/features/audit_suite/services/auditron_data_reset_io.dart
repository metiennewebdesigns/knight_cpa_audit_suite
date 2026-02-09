import 'dart:io' show Directory;

import 'package:path/path.dart' as p;

import '../../../core/utils/doc_path.dart';

Future<void> resetAuditronLocalData() async {
  final docsPath = await getDocumentsPath();
  if (docsPath == null || docsPath.isEmpty) {
    throw StateError('Documents directory not available.');
  }

  final root = Directory(p.join(docsPath, 'Auditron'));
  if (await root.exists()) {
    await root.delete(recursive: true);
  }
}