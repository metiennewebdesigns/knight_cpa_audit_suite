// lib/features/audit_suite/services/file_save_open.dart
//
// Platform-safe save/open API.
// - Provides a standalone function (analyzer-proof)
// - ALSO provides the legacy extension method used across screens

import 'dart:typed_data';
import 'package:flutter/widgets.dart';

import 'file_save_open_stub.dart'
    if (dart.library.io) 'file_save_open_io.dart' as impl;

class PdfSaveResult {
  final String savedPath;
  final String savedFileName;
  final bool didOpenFile;

  const PdfSaveResult({
    required this.savedPath,
    required this.savedFileName,
    required this.didOpenFile,
  });
}

/// ✅ Standalone function (preferred, analyzer-proof)
Future<PdfSaveResult> savePdfBytesAndMaybeOpenStandalone({
  required String fileName,
  required Uint8List bytes,
  String subfolder = 'auditron/exports',
  bool openAfterSave = true,
}) {
  return impl.savePdfBytesAndMaybeOpenStandalone(
    fileName: fileName,
    bytes: bytes,
    subfolder: subfolder,
    openAfterSave: openAfterSave,
  );
}

/// ✅ Legacy extension method (keeps older screens green)
extension PdfSaveOpenStateX on State {
  Future<PdfSaveResult> savePdfBytesAndMaybeOpen({
    required String fileName,
    Uint8List? bytes, // legacy name
    Uint8List? pdfBytes, // alias
    String subfolder = 'auditron/exports',
    bool openAfterSave = true,
  }) {
    final data = bytes ?? pdfBytes;
    if (data == null) {
      throw ArgumentError('savePdfBytesAndMaybeOpen requires bytes (or pdfBytes).');
    }
    return savePdfBytesAndMaybeOpenStandalone(
      fileName: fileName,
      bytes: data,
      subfolder: subfolder,
      openAfterSave: openAfterSave,
    );
  }
}