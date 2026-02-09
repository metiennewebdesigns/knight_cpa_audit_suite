// lib/features/audit_suite/services/deliverable_pack_exporter.dart
//
// Platform-safe DeliverablePackExporter:
// - Web: compiles, export disabled (no filesystem / open_filex)
// - IO (macOS/Windows/Linux): real PDF export + open file

export 'deliverable_pack_exporter_stub.dart'
    if (dart.library.io) 'deliverable_pack_exporter_io.dart';