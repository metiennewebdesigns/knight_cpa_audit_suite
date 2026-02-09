// Platform-safe Export History:
// - Web: compiles, returns empty (no filesystem scanning)
// - IO: scans Auditron export folders + reads letters meta

export 'export_history_stub.dart'
    if (dart.library.io) 'export_history_io.dart';