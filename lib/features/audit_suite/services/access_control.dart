import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum AppRole {
  owner,
  manager,
  staff,
  client,
}

class AccessControl {
  static const _kRole = 'auditron_role';
  static const _kDemo = 'auditron_demo_mode';

  static String roleLabel(AppRole r) {
    switch (r) {
      case AppRole.owner:
        return 'Owner';
      case AppRole.manager:
        return 'Manager';
      case AppRole.staff:
        return 'Staff';
      case AppRole.client:
        return 'Client';
    }
  }

  static AppRole parseRole(String raw) {
    final v = raw.trim().toLowerCase();
    for (final r in AppRole.values) {
      if (r.name.toLowerCase() == v) return r;
    }
    return AppRole.owner;
  }

  static Future<AppRole> getRole() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kRole) ?? AppRole.owner.name;
    return parseRole(raw);
  }

  static Future<void> setRole(AppRole role) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kRole, role.name);
  }

  static Future<bool> isDemoMode() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_kDemo) ?? false;
  }

  static Future<void> setDemoMode(bool v) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kDemo, v);
  }

  /// Convenience: what the UI should allow.
  static bool canExportPdfs(AppRole role) => role != AppRole.client;
  static bool canOpenEvidenceLedger(AppRole role) => role != AppRole.client;
  static bool canUseQuickExports(AppRole role) => role == AppRole.owner || role == AppRole.manager;

  /// Small helper for debugging/logging
  static String toJson(AppRole role, bool demoMode) {
    return jsonEncode({'role': role.name, 'demoMode': demoMode});
  }
}