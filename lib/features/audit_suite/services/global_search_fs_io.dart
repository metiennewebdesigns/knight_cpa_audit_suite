import 'dart:convert';
import 'dart:io' show Directory, File;

import 'package:path/path.dart' as p;

Future<List<PbcSearchHit>> listPbcSearchHits({
  required String docsPath,
  int maxPerEngagement = 200,
}) async {
  final out = <PbcSearchHit>[];

  final pbcDir = Directory(p.join(docsPath, 'Auditron', 'PBC'));
  if (!await pbcDir.exists()) return out;

  final files = pbcDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.toLowerCase().endsWith('.json'))
      .toList();

  for (final f in files) {
    final engagementId = p.basenameWithoutExtension(f.path);

    try {
      final raw = await f.readAsString();
      if (raw.trim().isEmpty) continue;

      final data = jsonDecode(raw) as Map<String, dynamic>;
      final list = (data['items'] as List<dynamic>? ?? const <dynamic>[]);

      int added = 0;
      for (final it in list) {
        if (it is! Map) continue;

        final title = (it['title'] ?? it['name'] ?? 'PBC Item').toString();
        final status = (it['status'] ?? '').toString();

        out.add(PbcSearchHit(
          engagementId: engagementId,
          title: title,
          status: status,
        ));

        added++;
        if (added >= maxPerEngagement) break;
      }
    } catch (_) {}
  }

  return out;
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