// lib/features/audit_suite/services/client_meta.dart
//
// Platform-safe ClientMeta:
// - Web: compiles, uses in-memory defaults (no filesystem)
// - IO: reads/writes Documents/Auditron/ClientMeta/{clientId}.json

export 'client_meta_stub.dart'
    if (dart.library.io) 'client_meta_io.dart';