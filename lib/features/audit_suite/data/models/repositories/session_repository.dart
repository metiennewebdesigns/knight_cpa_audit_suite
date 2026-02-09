import 'dart:convert';

import '../../../../../core/storage/local_store.dart';
import '../session_models.dart';

class SessionRepository {
  SessionRepository(this.store);

  final LocalStore store;

  static const _key = 'demo_session_v1';

  SessionModel get current {
    final raw = store.prefs.getString(_key);
    if (raw == null || raw.trim().isEmpty) {
      return const SessionModel(userId: 'u_client', name: 'Client User', role: UserRole.client);
    }
    return SessionModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> set(SessionModel s) async {
    await store.prefs.setString(_key, jsonEncode(s.toJson()));
  }

  Future<void> reset() async {
    await store.prefs.remove(_key);
  }
}