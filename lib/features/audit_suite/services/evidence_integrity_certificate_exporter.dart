// lib/features/audit_suite/services/evidence_integrity_certificate_exporter.dart
//
// Platform-safe EvidenceIntegrityCertificateExporter:
// - Web: compiles, export disabled (no filesystem / open_filex)
// - IO (macOS/Windows/Linux): real PDF export + open file

export 'evidence_integrity_certificate_exporter_stub.dart'
    if (dart.library.io) 'evidence_integrity_certificate_exporter_io.dart';