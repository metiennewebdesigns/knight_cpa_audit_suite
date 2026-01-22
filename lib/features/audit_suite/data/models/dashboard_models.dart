class DashboardData {
  const DashboardData({
    required this.clients,
    required this.engagementmentsCount,
    required this.workpapers,
    required this.recentClients,
    required this.engagementsList,
  });

  final int clients;
  final int engagementmentsCount; // keep count separate from list
  final int workpapers;

  final List<ClientSummary> recentClients;
  final List<EngagementSummary> engagementsList;

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    final recent = (json['recentClients'] as List?)
            ?.whereType<Map>()
            .map((m) => ClientSummary.fromJson(m.cast<String, dynamic>()))
            .toList() ??
        const <ClientSummary>[];

    final engagements = (json['engagementsList'] as List?)
            ?.whereType<Map>()
            .map((m) => EngagementSummary.fromJson(m.cast<String, dynamic>()))
            .toList() ??
        const <EngagementSummary>[];

    return DashboardData(
      clients: _toInt(json['clients']),
      engagementmentsCount: _toInt(json['engagements']),
      workpapers: _toInt(json['workpapers']),
      recentClients: recent,
      engagementsList: engagements,
    );
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse((v ?? '0').toString()) ?? 0;
  }
}

class ClientSummary {
  const ClientSummary({
    required this.id,
    required this.name,
    required this.cityState,
    required this.updated,
    required this.statusLabel,
  });

  final String id;
  final String name;
  final String cityState;
  final String updated;
  final String statusLabel;

  factory ClientSummary.fromJson(Map<String, dynamic> json) {
    return ClientSummary(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      cityState: (json['cityState'] ?? '').toString(),
      updated: (json['updated'] ?? '').toString(),
      statusLabel: (json['statusLabel'] ?? '').toString(),
    );
  }
}

class EngagementSummary {
  const EngagementSummary({
    required this.id,
    required this.clientName,
    required this.entityType,
    required this.jurisdiction,
    required this.taxYears,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String clientName;
  final String entityType;
  final String jurisdiction;
  final String taxYears;
  final String status;
  final String createdAt;
  final String updatedAt;

  factory EngagementSummary.fromJson(Map<String, dynamic> json) {
    return EngagementSummary(
      id: (json['id'] ?? '').toString(),
      clientName: (json['clientName'] ?? '').toString(),
      entityType: (json['entityType'] ?? '').toString(),
      jurisdiction: (json['jurisdiction'] ?? '').toString(),
      taxYears: (json['taxYears'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      createdAt: (json['createdAt'] ?? '').toString(),
      updatedAt: (json['updatedAt'] ?? '').toString(),
    );
  }
}