class ClientModel {
  final String id;
  final String name;
  final String location;
  final String status; // Active / Inactive
  final String updated; // ISO date YYYY-MM-DD

  const ClientModel({
    required this.id,
    required this.name,
    required this.location,
    required this.status,
    required this.updated,
  });

  factory ClientModel.fromJson(Map<String, dynamic> json) {
    return ClientModel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      location: (json['location'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      updated: (json['updated'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'location': location,
      'status': status,
      'updated': updated,
    };
  }

  ClientModel copyWith({
    String? id,
    String? name,
    String? location,
    String? status,
    String? updated,
  }) {
    return ClientModel(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      status: status ?? this.status,
      updated: updated ?? this.updated,
    );
  }
}