class WorkpaperModel {
  final String id;
  final String engagementId;
  final String title;
  final String status; // Open / In Progress / Complete
  final String updated; // yyyy-mm-dd
  final String type; // xlsx / pdf / docx
  final List<WorkpaperAttachmentModel> attachments;

  const WorkpaperModel({
    required this.id,
    required this.engagementId,
    required this.title,
    required this.status,
    required this.updated,
    required this.type,
    this.attachments = const [],
  });

  WorkpaperModel copyWith({
    String? id,
    String? engagementId,
    String? title,
    String? status,
    String? updated,
    String? type,
    List<WorkpaperAttachmentModel>? attachments,
  }) {
    return WorkpaperModel(
      id: id ?? this.id,
      engagementId: engagementId ?? this.engagementId,
      title: title ?? this.title,
      status: status ?? this.status,
      updated: updated ?? this.updated,
      type: type ?? this.type,
      attachments: attachments ?? this.attachments,
    );
  }

  factory WorkpaperModel.fromJson(Map<String, dynamic> json) {
    final rawAttachments = (json['attachments'] as List<dynamic>?) ?? const [];
    return WorkpaperModel(
      id: (json['id'] ?? '').toString(),
      engagementId: (json['engagementId'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      status: (json['status'] ?? 'Open').toString(),
      updated: (json['updated'] ?? '').toString(),
      type: (json['type'] ?? 'xlsx').toString(),
      attachments: rawAttachments
          .map((e) => WorkpaperAttachmentModel.fromJson(
                e as Map<String, dynamic>,
              ))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'engagementId': engagementId,
      'title': title,
      'status': status,
      'updated': updated,
      'type': type,
      'attachments': attachments.map((a) => a.toJson()).toList(),
    };
  }
}

class WorkpaperAttachmentModel {
  final String id;
  final String name; // original filename
  final String localPath; // sandboxed path on device
  final int sizeBytes;
  final String addedAtIso; // ISO timestamp

  const WorkpaperAttachmentModel({
    required this.id,
    required this.name,
    required this.localPath,
    required this.sizeBytes,
    required this.addedAtIso,
  });

  WorkpaperAttachmentModel copyWith({
    String? id,
    String? name,
    String? localPath,
    int? sizeBytes,
    String? addedAtIso,
  }) {
    return WorkpaperAttachmentModel(
      id: id ?? this.id,
      name: name ?? this.name,
      localPath: localPath ?? this.localPath,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      addedAtIso: addedAtIso ?? this.addedAtIso,
    );
  }

  factory WorkpaperAttachmentModel.fromJson(Map<String, dynamic> json) {
    return WorkpaperAttachmentModel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      localPath: (json['localPath'] ?? '').toString(),
      sizeBytes: (json['sizeBytes'] ?? 0) as int,
      addedAtIso: (json['addedAtIso'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'localPath': localPath,
      'sizeBytes': sizeBytes,
      'addedAtIso': addedAtIso,
    };
  }
}