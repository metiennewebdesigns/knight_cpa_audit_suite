// lib/features/audit_suite/services/reveal_folder.dart
//
// Platform-safe folder reveal:
// - Web: no-op stub (keeps compile clean)
// - IO: opens the folder in Finder/Explorer/File Manager

export 'reveal_folder_stub.dart'
    if (dart.library.io) 'reveal_folder_io.dart';