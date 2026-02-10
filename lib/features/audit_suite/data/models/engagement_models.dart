class EngagementModel {
  final String id;
  final String clientId;
  final String title;

  /// Open | In Progress | Complete | Finalized | Archived
  final String status;

  /// yyyy-mm-dd
  final String updated;

  // ===================== AI PRIORITY (NEW) =====================
  /// Low | Medium | High | Critical
  final String aiPriorityLabel;

  /// 0-100
  final int aiPriorityScore;

  /// short explanation for trust
  final String aiPriorityReason;

  /// ISO timestamp of last update
  final String aiPriorityUpdatedAt;

  const EngagementModel({
    required this.id,
    required this.clientId,
    required this.title,
    required this.status,
    required this.updated,
    this.aiPriorityLabel = '',
    this.aiPriorityScore = 0,
    this.aiPriorityReason = '',
    this.aiPriorityUpdatedAt = '',
  });

  // ---- Derived flags used throughout UI ----
  bool get isFinalized => status.trim().toLowerCase() == 'finalized';
  bool get isArchived => status.trim().toLowerCase() == 'archived';

  bool get hasAiPriority =>
      aiPriorityLabel.trim().isNotEmpty ||
      aiPriorityScore > 0 ||
      aiPriorityReason.trim().isNotEmpty;

  EngagementModel copyWith({
    String? id,
    String? clientId,
    String? title,
    String? status,
    String? updated,
    String? aiPriorityLabel,
    int? aiPriorityScore,
    String? aiPriorityReason,
    String? aiPriorityUpdatedAt,
  }) {
    return EngagementModel(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      title: title ?? this.title,
      status: status ?? this.status,
      updated: updated ?? this.updated,
      aiPriorityLabel: aiPriorityLabel ?? this.aiPriorityLabel,
      aiPriorityScore: aiPriorityScore ?? this.aiPriorityScore,
      aiPriorityReason: aiPriorityReason ?? this.aiPriorityReason,
      aiPriorityUpdatedAt: aiPriorityUpdatedAt ?? this.aiPriorityUpdatedAt,
    );
  }

  factory EngagementModel.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse('$v') ?? 0;
    }

    return EngagementModel(
      id: (json['id'] ?? '').toString(),
      clientId: (json['clientId'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      status: (json['status'] ?? 'Open').toString(),
      updated: (json['updated'] ?? '').toString(),
      aiPriorityLabel: (json['aiPriorityLabel'] ?? '').toString(),
      aiPriorityScore: asInt(json['aiPriorityScore']),
      aiPriorityReason: (json['aiPriorityReason'] ?? '').toString(),
      aiPriorityUpdatedAt: (json['aiPriorityUpdatedAt'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'clientId': clientId,
        'title': title,
        'status': status,
        'updated': updated,
        'aiPriorityLabel': aiPriorityLabel,
        'aiPriorityScore': aiPriorityScore,
        'aiPriorityReason': aiPriorityReason,
        'aiPriorityUpdatedAt': aiPriorityUpdatedAt,
      };
}