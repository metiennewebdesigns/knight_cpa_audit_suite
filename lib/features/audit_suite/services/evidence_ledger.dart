// lib/features/audit_suite/services/evidence_ledger.dart
//
// Platform-safe Evidence Ledger:
// - Web: compiles, returns disabled results (no crashes)
// - IO (macOS/Windows/Linux/mobile): real filesystem + hashing

export 'evidence_ledger_stub.dart'
    if (dart.library.io) 'evidence_ledger_io.dart';