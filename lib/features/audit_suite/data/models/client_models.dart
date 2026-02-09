class ClientModel {
  final String id;
  final String name;
  final String location;
  final String status; // Active / Inactive
  final String updated; // ISO date YYYY-MM-DD

  // ✅ NEW fields
  final String taxId;
  final String email;
  final String phone;

  const ClientModel({
    required this.id,
    required this.name,
    required this.location,
    required this.status,
    required this.updated,
    required this.taxId,
    required this.email,
    required this.phone,
  });

  factory ClientModel.fromJson(Map<String, dynamic> json) {
    return ClientModel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      location: (json['location'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      updated: (json['updated'] ?? '').toString(),

      // ✅ Backwards compatible (older saved clients won’t have these)
      taxId: (json['taxId'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'location': location,
      'status': status,
      'updated': updated,

      // ✅ NEW fields
      'taxId': taxId,
      'email': email,
      'phone': phone,
    };
  }

  ClientModel copyWith({
    String? id,
    String? name,
    String? location,
    String? status,
    String? updated,
    String? taxId,
    String? email,
    String? phone,
  }) {
    return ClientModel(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      status: status ?? this.status,
      updated: updated ?? this.updated,
      taxId: taxId ?? this.taxId,
      email: email ?? this.email,
      phone: phone ?? this.phone,
    );
  }
}