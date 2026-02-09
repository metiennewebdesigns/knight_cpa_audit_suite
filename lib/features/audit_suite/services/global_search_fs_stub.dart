/// Returns a list of PBC items found on disk across engagements.
/// Web demo: returns empty (no filesystem).
Future<List<PbcSearchHit>> listPbcSearchHits({
  required String docsPath,
  int maxPerEngagement = 200,
}) async {
  return const <PbcSearchHit>[];
}

class PbcSearchHit {
  final String engagementId;
  final String title;
  final String status;

  const PbcSearchHit({
    required this.engagementId,
    required this.title,
    required this.status,
  });
}