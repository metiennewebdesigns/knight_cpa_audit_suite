// lib/features/audit_suite/services/client_portal_audit_exporter.dart
//
// Platform-safe ClientPortalAuditExporter:
// - Web: compiles, export disabled
// - IO: real PDF export + open file

export 'client_portal_audit_exporter_stub.dart'
    if (dart.library.io) 'client_portal_audit_exporter_io.dart';