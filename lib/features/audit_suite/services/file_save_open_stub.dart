// lib/features/audit_suite/services/file_save_open_stub.dart
//
// Web-safe stub.

import 'dart:typed_data';

import 'file_save_open.dart';

Future<PdfSaveResult> savePdfBytesAndMaybeOpenStandalone({
  required String fileName,
  required Uint8List bytes,
  String subfolder = 'auditron/exports',
  bool openAfterSave = true,
}) async {
  return PdfSaveResult(
    savedPath: '',
    savedFileName: fileName,
    didOpenFile: false,
  );
}