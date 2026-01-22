class DashboardRepository {
  /// Temporary demo counts (replace with real persistence later).
  Future<DashboardCounts> getCounts() async {
    return const DashboardCounts(
      clientsCount: 12,
      engagementsCount: 2,
      workpapersCount: 34,
    );
  }
}

class DashboardCounts {
  final int clientsCount;
  final int engagementsCount;
  final int workpapersCount;

  const DashboardCounts({
    required this.clientsCount,
    required this.engagementsCount,
    required this.workpapersCount,
  });
}