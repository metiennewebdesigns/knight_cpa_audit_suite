import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/storage/local_store.dart';
import 'core/router/app_router.dart' as core_router;

/// Single source of truth router.
/// This file exists only so older imports (lib/app_router.dart) keep working.
GoRouter buildRouter({
  required LocalStore store,
  required ValueNotifier<ThemeMode> themeMode,
}) {
  return core_router.buildRouter(store: store, themeMode: themeMode);
}