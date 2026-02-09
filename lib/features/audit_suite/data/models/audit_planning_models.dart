class AuditPlanningSummaryModel {
  final String id;
  final String engagementId;
  final String updated; // yyyy-mm-dd

  // what the UI expects
  final String overallLevel; // Low / Medium / High
  final int overallScore1to5; // 1..5

  final String status; // Draft / Generated / Final etc
  final String narrative; // generated narrative text

  const AuditPlanningSummaryModel({
    required this.id,
    required this.engagementId,
    required this.updated,
    required this.overallLevel,
    required this.overallScore1to5,
    required this.status,
    required this.narrative,
  });

  AuditPlanningSummaryModel copyWith({
    String? id,
    String? engagementId,
    String? updated,
    String? overallLevel,
    int? overallScore1to5,
    String? status,
    String? narrative,
  }) {
    return AuditPlanningSummaryModel(
      id: id ?? this.id,
      engagementId: engagementId ?? this.engagementId,
      updated: updated ?? this.updated,
      overallLevel: overallLevel ?? this.overallLevel,
      overallScore1to5: overallScore1to5 ?? this.overallScore1to5,
      status: status ?? this.status,
      narrative: narrative ?? this.narrative,
    );
  }

  factory AuditPlanningSummaryModel.emptyForEngagement(String engagementId) {
    return AuditPlanningSummaryModel(
      id: '',
      engagementId: engagementId,
      updated: '',
      overallLevel: 'Low',
      overallScore1to5: 1,
      status: 'Draft',
      narrative: '',
    );
  }

  factory AuditPlanningSummaryModel.fromJson(Map<String, dynamic> json) {
    return AuditPlanningSummaryModel(
      id: (json['id'] ?? '').toString(),
      engagementId: (json['engagementId'] ?? '').toString(),
      updated: (json['updated'] ?? '').toString(),
      overallLevel: (json['overallLevel'] ?? 'Low').toString(),
      overallScore1to5:
          int.tryParse((json['overallScore1to5'] ?? 1).toString()) ?? 1,
      status: (json['status'] ?? 'Draft').toString(),
      narrative: (json['narrative'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'engagementId': engagementId,
        'updated': updated,
        'overallLevel': overallLevel,
        'overallScore1to5': overallScore1to5,
        'status': status,
        'narrative': narrative,
      };
}