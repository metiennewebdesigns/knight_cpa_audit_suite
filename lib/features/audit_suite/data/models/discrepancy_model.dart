class DiscrepancyModel {
  final String id;
  final String engagementId;

  final String title;
  final String description;

  /// positive numbers only for MVP
  final double amount;

  /// open | resolved
  final String status;

  /// free text for now (later can be a user id)
  final String assignedTo;

  final String createdAtIso;
  final String resolvedAtIso;

  const DiscrepancyModel({
    required this.id,
    required this.engagementId,
    required this.title,
    required this.description,
    required this.amount,
    required this.status,
    required this.assignedTo,
    required this.createdAtIso,
    required this.resolvedAtIso,
  });

  bool get isOpen => status.toLowerCase() != 'resolved';

  DiscrepancyModel copyWith({
    String? id,
    String? engagementId,
    String? title,
    String? description,
    double? amount,
    String? status,
    String? assignedTo,
    String? createdAtIso,
    String? resolvedAtIso,
  }) {
    return DiscrepancyModel(
      id: id ?? this.id,
      engagementId: engagementId ?? this.engagementId,
      title: title ?? this.title,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      assignedTo: assignedTo ?? this.assignedTo,
      createdAtIso: createdAtIso ?? this.createdAtIso,
      resolvedAtIso: resolvedAtIso ?? this.resolvedAtIso,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'engagementId': engagementId,
        'title': title,
        'description': description,
        'amount': amount,
        'status': status,
        'assignedTo': assignedTo,
        'createdAtIso': createdAtIso,
        'resolvedAtIso': resolvedAtIso,
      };

  static DiscrepancyModel fromJson(Map<String, dynamic> j) {
    double dnum(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse('$v') ?? 0.0;
    }

    return DiscrepancyModel(
      id: (j['id'] ?? '').toString(),
      engagementId: (j['engagementId'] ?? '').toString(),
      title: (j['title'] ?? '').toString(),
      description: (j['description'] ?? '').toString(),
      amount: dnum(j['amount']),
      status: (j['status'] ?? 'open').toString(),
      assignedTo: (j['assignedTo'] ?? '').toString(),
      createdAtIso: (j['createdAtIso'] ?? '').toString(),
      resolvedAtIso: (j['resolvedAtIso'] ?? '').toString(),
    );
  }
}