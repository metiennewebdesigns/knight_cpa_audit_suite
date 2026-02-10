// lib/features/audit_suite/services/pbc_pdf_exporter.dart
//
// Platform-safe exporter:
// - Web: stub (compile-safe, returns a valid result object)
// - IO: real PDF export + save/open

export 'pbc_pdf_exporter_stub.dart'
    if (dart.library.io) 'pbc_pdf_exporter_io.dart';