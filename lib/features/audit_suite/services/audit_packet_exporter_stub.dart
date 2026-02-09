// lib/features/audit_suite/services/audit_packet_exporter_stub.dart
//
// Web implementation: packet export disabled (needs filesystem + zip).

import '../../../core/storage/local_store.dart';
import '../data/models/client_models.dart';
import '../data/models/engagement_models.dart';
import '../data/models/risk_assessment_models.dart';
import '../data/models/workpaper_models.dart';

class ExportResultPaths {
  final String pdfPath;
  final String zipPath;

  const ExportResultPaths({
    required this.pdfPath,
    required this.zipPath,
  });
}

class CopyRow {
  final String scope;
  final String parent;
  final String file;
  final String status;

  const CopyRow({
    required this.scope,
    required this.parent,
    required this.file,
    required this.status,
  });
}

class AuditPacketExporter {
  static Future<ExportResultPaths> exportPacketAndZip({
    required LocalStore store,
    required EngagementModel engagement,
    required ClientModel? client,
    required RiskAssessmentModel risk,
    required List<WorkpaperModel> workpapers,
    required String pbcPrefsKey,
  }) async {
    throw UnsupportedError('Audit Packet export is disabled on web demo.');
  }
}