import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/doc_path.dart';

class LocalStore {
  /// Documents folder path for desktop/mobile. NULL on web.
  final String? documentsPath;

  /// SharedPreferences works on web + desktop.
  final SharedPreferences prefs;

  LocalStore._({
    required this.documentsPath,
    required this.prefs,
  });

  /// Initialize once at app startup.
  static Future<LocalStore> init() async {
    final prefs = await SharedPreferences.getInstance();

    if (kIsWeb) {
      return LocalStore._(
        documentsPath: null,
        prefs: prefs,
      );
    }

    final path = await getDocumentsPath();
    return LocalStore._(
      documentsPath: (path != null && path.trim().isNotEmpty) ? path : null,
      prefs: prefs,
    );
  }

  /// True only when we can safely read/write local files.
  bool get canUseFileSystem =>
      !kIsWeb && documentsPath != null && documentsPath!.trim().isNotEmpty;

  /// Build an absolute path under Documents.
  /// Returns null on web.
  String? resolvePath(String relativePath) {
    if (!canUseFileSystem) return null;

    final base = documentsPath!.trim();
    if (relativePath.trim().isEmpty) return base;

    final needsSlash = !base.endsWith('/') && !relativePath.startsWith('/');
    return needsSlash ? '$base/$relativePath' : '$base$relativePath';
  }

  String get fileSystemDisabledReason =>
      'File exports/logs are disabled on web (no local Documents folder).';
}