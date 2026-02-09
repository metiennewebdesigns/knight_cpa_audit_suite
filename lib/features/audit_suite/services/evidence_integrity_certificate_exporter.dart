// lib/features/audit_suite/services/evidence_integrity_certificate_exporter.dart
//
// Platform-safe certificate exporter:
// - Web: compiles, export disabled
// - IO: real PDF export + open file

export 'evidence_integrity_certificate_exporter_stub.dart'
    if (dart.library.io) 'evidence_integrity_certificate_exporter_io.dart';