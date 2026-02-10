// lib/features/audit_suite/services/export_history.dart
//
// Platform-safe export history API.
// - Web: stub (empty/no-op)
// - IO: real persistence

export 'export_history_stub.dart'
    if (dart.library.io) 'export_history_io.dart';