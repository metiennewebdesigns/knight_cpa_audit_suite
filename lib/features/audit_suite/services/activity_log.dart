// lib/features/audit_suite/services/activity_log.dart
//
// Platform-safe ActivityLog:
// - Web: compiles, returns empty/no-op
// - IO: appends/reads a JSONL activity feed in Documents/Auditron/Activity/activity.jsonl

export 'activity_log_stub.dart'
    if (dart.library.io) 'activity_log_io.dart';
