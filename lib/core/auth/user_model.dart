class AuditUser {
  final String id;
  final String name;
  final String email;
  final String role; // owner | manager | staff | reviewer

  const AuditUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });
}