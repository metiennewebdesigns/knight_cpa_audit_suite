// lib/features/audit_suite/services/letter_exporter.dart
//
// Platform-safe LetterExporter:
// - Web: compiles, export disabled (no filesystem / open_filex)
// - IO (macOS/Windows/Linux): real PDF export + open file + ActivityLog entry

export 'letter_exporter_stub.dart'
    if (dart.library.io) 'letter_exporter_io.dart';