import 'dart:math';

class RiskAssessmentModel {
  final String id;
  final String engagementId;
  final String updated; // yyyy-mm-dd
  final List<RiskItemModel> items;

  const RiskAssessmentModel({
    required this.id,
    required this.engagementId,
    required this.updated,
    required this.items,
  });

  RiskAssessmentModel copyWith({
    String? id,
    String? engagementId,
    String? updated,
    List<RiskItemModel>? items,
  }) {
    return RiskAssessmentModel(
      id: id ?? this.id,
      engagementId: engagementId ?? this.engagementId,
      updated: updated ?? this.updated,
      items: items ?? this.items,
    );
  }

  factory RiskAssessmentModel.emptyForEngagement(String engagementId) {
    return RiskAssessmentModel(
      id: '',
      engagementId: engagementId,
      updated: '',
      items: RiskItemModel.defaultItems(),
    );
  }

  /// Average numeric score (1-5) across all items.
  int overallScore1to5() {
    if (items.isEmpty) return 1;
    final avg = items.map((e) => e.score1to5).reduce((a, b) => a + b) / items.length;
    return max(1, min(5, avg.round()));
  }

  /// L/M/H derived from overall numeric score.
  String overallLevel() {
    final s = overallScore1to5();
    if (s <= 2) return 'Low';
    if (s == 3) return 'Medium';
    return 'High';
  }

  factory RiskAssessmentModel.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List<dynamic>? ?? const <dynamic>[]);
    return RiskAssessmentModel(
      id: (json['id'] ?? '').toString(),
      engagementId: (json['engagementId'] ?? '').toString(),
      updated: (json['updated'] ?? '').toString(),
      items: rawItems
          .map((e) => RiskItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'engagementId': engagementId,
        'updated': updated,
        'items': items.map((e) => e.toJson()).toList(),
      };
}

class RiskItemModel {
  final String id;
  final String category; // e.g., "Inherent Risk"
  final String prompt;   // e.g., "Complex transactions?"
  final String level;    // Low|Medium|High
  final int score1to5;   // 1..5
  final String notes;

  const RiskItemModel({
    required this.id,
    required this.category,
    required this.prompt,
    required this.level,
    required this.score1to5,
    required this.notes,
  });

  RiskItemModel copyWith({
    String? id,
    String? category,
    String? prompt,
    String? level,
    int? score1to5,
    String? notes,
  }) {
    return RiskItemModel(
      id: id ?? this.id,
      category: category ?? this.category,
      prompt: prompt ?? this.prompt,
      level: level ?? this.level,
      score1to5: score1to5 ?? this.score1to5,
      notes: notes ?? this.notes,
    );
  }

  factory RiskItemModel.fromJson(Map<String, dynamic> json) {
    return RiskItemModel(
      id: (json['id'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      prompt: (json['prompt'] ?? '').toString(),
      level: (json['level'] ?? 'Low').toString(),
      score1to5: int.tryParse((json['score1to5'] ?? 1).toString()) ?? 1,
      notes: (json['notes'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'prompt': prompt,
        'level': level,
        'score1to5': score1to5,
        'notes': notes,
      };

  static List<RiskItemModel> defaultItems() {
    return const [
      RiskItemModel(
        id: 'ra-inherent-1',
        category: 'Inherent Risk',
        prompt: 'Complex estimates or judgments involved?',
        level: 'Medium',
        score1to5: 3,
        notes: '',
      ),
      RiskItemModel(
        id: 'ra-control-1',
        category: 'Control Risk',
        prompt: 'Weaknesses in internal controls suspected?',
        level: 'Medium',
        score1to5: 3,
        notes: '',
      ),
      RiskItemModel(
        id: 'ra-fraud-1',
        category: 'Fraud Risk',
        prompt: 'Fraud incentives / pressure present?',
        level: 'Low',
        score1to5: 2,
        notes: '',
      ),
      RiskItemModel(
        id: 'ra-compliance-1',
        category: 'Compliance Risk',
        prompt: 'High regulatory/compliance exposure?',
        level: 'Low',
        score1to5: 2,
        notes: '',
      ),
      RiskItemModel(
        id: 'ra-fs-1',
        category: 'Financial Statement Risk',
        prompt: 'Prior period issues or material adjustments expected?',
        level: 'Medium',
        score1to5: 3,
        notes: '',
      ),
    ];
  }
}