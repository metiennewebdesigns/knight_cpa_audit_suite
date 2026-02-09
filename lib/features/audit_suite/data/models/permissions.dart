import 'session_models.dart';

class PermissionError implements Exception {
  PermissionError(this.message);
  final String message;

  @override
  String toString() => message;
}

class Permissions {
  static bool canManageClients(UserRole role) => role != UserRole.client;

  static bool canCreateEditDeleteEngagement(UserRole role) =>
      role == UserRole.staff || role == UserRole.cpa || role == UserRole.admin;

  static bool canFinalizeEngagement(UserRole role) =>
      role == UserRole.cpa || role == UserRole.admin;

  static bool canCreateEditDeleteWorkpaper(UserRole role) =>
      role == UserRole.staff || role == UserRole.cpa || role == UserRole.admin;

  static bool canCreateEditDeletePbc(UserRole role) =>
      role == UserRole.staff || role == UserRole.cpa || role == UserRole.admin;

  static bool canAttachFiles(UserRole role) => true; // client allowed (until finalized)

  static void require(bool condition, String message) {
    if (!condition) throw PermissionError(message);
  }
}