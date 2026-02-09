class EngagementModel {
  final String id;
  final String clientId;
  final String title;

  /// Open | In Progress | Complete | Finalized | Archived
  final String status;

  /// yyyy-mm-dd
  final String updated;

  const EngagementModel({
    required this.id,
    required this.clientId,
    required this.title,
    required this.status,
    required this.updated,
  });

  // ---- Derived flags used throughout UI ----
  bool get isFinalized => status.trim().toLowerCase() == 'finalized';
  bool get isArchived => status.trim().toLowerCase() == 'archived';

  EngagementModel copyWith({
    String? id,
    String? clientId,
    String? title,
    String? status,
    String? updated,
  }) {
    return EngagementModel(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      title: title ?? this.title,
      status: status ?? this.status,
      updated: updated ?? this.updated,
    );
  }

  factory EngagementModel.fromJson(Map<String, dynamic> json) {
    return EngagementModel(
      id: (json['id'] ?? '').toString(),
      clientId: (json['clientId'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      status: (json['status'] ?? 'Open').toString(),
      updated: (json['updated'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'clientId': clientId,
        'title': title,
        'status': status,
        'updated': updated,
      };
}