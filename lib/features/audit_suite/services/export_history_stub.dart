import '../../../core/storage/local_store.dart';

class ExportHistoryVm {
  final int deliverablePackCount;
  final String deliverableLastIso;

  final int auditPacketCount;
  final String packetLastIso;

  final int integrityCertCount;
  final String certLastIso;

  final int portalAuditCount;
  final String portalAuditLastIso;

  final int lettersCount;
  final String lettersLastIso;

  const ExportHistoryVm({
    required this.deliverablePackCount,
    required this.deliverableLastIso,
    required this.auditPacketCount,
    required this.packetLastIso,
    required this.integrityCertCount,
    required this.certLastIso,
    required this.portalAuditCount,
    required this.portalAuditLastIso,
    required this.lettersCount,
    required this.lettersLastIso,
  });

  static const empty = ExportHistoryVm(
    deliverablePackCount: 0,
    deliverableLastIso: '',
    auditPacketCount: 0,
    packetLastIso: '',
    integrityCertCount: 0,
    certLastIso: '',
    portalAuditCount: 0,
    portalAuditLastIso: '',
    lettersCount: 0,
    lettersLastIso: '',
  );
}

class ExportHistoryReader {
  static Future<ExportHistoryVm> load(LocalStore store, String engagementId) async {
    // Web/demo: no folder scanning
    return ExportHistoryVm.empty;
  }
}