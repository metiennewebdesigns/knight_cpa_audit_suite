class PbcItemModel {
  final String id;
  final String engagementId;

  /// What you’re requesting from client (PBC request)
  final String request;

  /// Open | Requested | Received | Cleared
  final String status;

  /// Who is responsible (client / staff)
  final String owner;

  /// yyyy-mm-dd (optional)
  final String dueDate;

  /// Optional notes
  final String notes;

  /// yyyy-mm-dd (last updated)
  final String updated;

  const PbcItemModel({
    required this.id,
    required this.engagementId,
    required this.request,
    required this.status,
    required this.owner,
    required this.dueDate,
    required this.notes,
    required this.updated,
  });

  PbcItemModel copyWith({
    String? id,
    String? engagementId,
    String? request,
    String? status,
    String? owner,
    String? dueDate,
    String? notes,
    String? updated,
  }) {
    return PbcItemModel(
      id: id ?? this.id,
      engagementId: engagementId ?? this.engagementId,
      request: request ?? this.request,
      status: status ?? this.status,
      owner: owner ?? this.owner,
      dueDate: dueDate ?? this.dueDate,
      notes: notes ?? this.notes,
      updated: updated ?? this.updated,
    );
  }

  factory PbcItemModel.fromJson(Map<String, dynamic> json) {
    return PbcItemModel(
      id: (json['id'] ?? '').toString(),
      engagementId: (json['engagementId'] ?? '').toString(),
      request: (json['request'] ?? '').toString(),
      status: (json['status'] ?? 'Open').toString(),
      owner: (json['owner'] ?? '').toString(),
      dueDate: (json['dueDate'] ?? '').toString(),
      notes: (json['notes'] ?? '').toString(),
      updated: (json['updated'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'engagementId': engagementId,
        'request': request,
        'status': status,
        'owner': owner,
        'dueDate': dueDate,
        'notes': notes,
        'updated': updated,
      };
}