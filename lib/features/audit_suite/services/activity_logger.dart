// lib/features/audit_suite/services/activity_logger.dart
//
// Platform-safe ActivityLogger:
// - Web: compiles, stores nothing (no filesystem)
// - IO: writes/reads JSONL in Documents/Auditron/Activity

export 'activity_logger_stub.dart'
    if (dart.library.io) 'activity_logger_io.dart';