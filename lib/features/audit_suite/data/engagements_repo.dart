class EngagementsRepo {
  Future<List<Engagement>> list() async {
    return const [
      Engagement(
        id: 'eng-001',
        title: 'FY 2025 Audit',
        clientName: 'The Goddess Collection',
        status: 'Active',
      ),
      Engagement(
        id: 'eng-002',
        title: 'Tax Prep + Review',
        clientName: 'DSG Luxury Transportation',
        status: 'In Review',
      ),
    ];
  }

  Future<Engagement?> byId(String id) async {
    final all = await list();
    try {
      return all.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }
}

class Engagement {
  final String id;
  final String title;
  final String clientName;
  final String status;

  const Engagement({
    required this.id,
    required this.title,
    required this.clientName,
    required this.status,
  });
}