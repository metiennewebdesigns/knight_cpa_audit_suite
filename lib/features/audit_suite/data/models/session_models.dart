enum UserRole { admin, cpa, staff, client }

UserRole roleFromString(String raw) {
  final s = raw.trim().toLowerCase();
  if (s == 'admin') return UserRole.admin;
  if (s == 'cpa') return UserRole.cpa;
  if (s == 'staff') return UserRole.staff;
  return UserRole.client;
}

String roleLabel(UserRole r) {
  switch (r) {
    case UserRole.admin:
      return 'Admin';
    case UserRole.cpa:
      return 'CPA';
    case UserRole.staff:
      return 'Staff';
    case UserRole.client:
      return 'Client';
  }
}

class SessionModel {
  final String userId;
  final String name;
  final UserRole role;

  const SessionModel({
    required this.userId,
    required this.name,
    required this.role,
  });

  SessionModel copyWith({
    String? userId,
    String? name,
    UserRole? role,
  }) {
    return SessionModel(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      role: role ?? this.role,
    );
  }

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return SessionModel(
      userId: (json['userId'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      role: roleFromString((json['role'] ?? 'client').toString()),
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'name': name,
        'role': roleLabel(role),
      };
}