class TimelineExportInfo {
  final int lettersGenerated;
  final String deliverableLastExportAt;
  final String packetLastExportAt;

  const TimelineExportInfo({
    required this.lettersGenerated,
    required this.deliverableLastExportAt,
    required this.packetLastExportAt,
  });
}

Future<TimelineExportInfo> scanTimelineExports(String engagementId) async {
  return const TimelineExportInfo(
    lettersGenerated: 0,
    deliverableLastExportAt: '',
    packetLastExportAt: '',
  );
}