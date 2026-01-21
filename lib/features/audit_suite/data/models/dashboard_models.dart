class DashboardData {
  const DashboardData({
    required this.clients,
    required this.engagements,
    required this.workpapers,
    required this.recentClients,
  });

  final int clients;
  final int engagements;
  final int workpapers;
  final List<ClientSummary> recentClients;

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      clients: _toInt(json['clients']),
      engagements: _toInt(json['engagements']),
      workpapers: _toInt(json['workpapers']),
      recentClients: _toClientList(json['recentClients']),
    );
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse((v ?? '0').toString()) ?? 0;
  }

  static List<ClientSummary> _toClientList(dynamic v) {
    if (v is! List) return const <ClientSummary>[];
    return v
        .whereType<Map>()
        .map((m) => ClientSummary.fromJson(m.cast<String, dynamic>()))
        .toList();
  }
}

class ClientSummary {
  const ClientSummary({
    required this.id,
    required this.name,
    required this.cityState,
    required this.updatedAt,
    required this.statusLabel,
  });

  final String id;
  final String name;
  final String cityState;
  final String updatedAt;
  final String statusLabel;

  factory ClientSummary.fromJson(Map<String, dynamic> json) {
    // Supports multiple possible keys so you don't keep getting "getter not defined" errors.
    final cityState = (json['cityState'] ?? json['location'] ?? '').toString();
    final updatedAt = (json['updatedAt'] ?? json['updated'] ?? '').toString();
    final statusLabel = (json['statusLabel'] ?? json['status'] ?? '').toString();

    return ClientSummary(
      id: (json['id'] ?? json['name'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      cityState: cityState,
      updatedAt: updatedAt,
      statusLabel: statusLabel,
    );
  }
}