// lib/features/audit_suite/services/preparer_profile.dart
//
// Platform-safe PreparerProfile:
// - Web: compiles, returns defaults, no-op saves
// - IO: reads/writes Documents/Auditron/Settings/preparer.json

export 'preparer_profile_stub.dart'
    if (dart.library.io) 'preparer_profile_io.dart';