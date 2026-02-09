// lib/features/audit_suite/services/audit_packet_exporter.dart
//
// Platform-safe AuditPacketExporter:
// - Web: compiles, export disabled
// - IO: real filesystem + zip + pdf

export 'audit_packet_exporter_stub.dart'
    if (dart.library.io) 'audit_packet_exporter_io.dart';