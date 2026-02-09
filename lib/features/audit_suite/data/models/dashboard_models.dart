class DashboardCounts {
  final int clientsCount;
  final int engagementsCount;
  final int workpapersCount;

  const DashboardCounts({
    required this.clientsCount,
    required this.engagementsCount,
    required this.workpapersCount,
  });

  Map<String, dynamic> toJson() => {
        'clientsCount': clientsCount,
        'engagementsCount': engagementsCount,
        'workpapersCount': workpapersCount,
      };

  factory DashboardCounts.fromJson(Map<String, dynamic> json) {
    return DashboardCounts(
      clientsCount: (json['clientsCount'] as num?)?.toInt() ?? 0,
      engagementsCount: (json['engagementsCount'] as num?)?.toInt() ?? 0,
      workpapersCount: (json['workpapersCount'] as num?)?.toInt() ?? 0,
    );
  }
}