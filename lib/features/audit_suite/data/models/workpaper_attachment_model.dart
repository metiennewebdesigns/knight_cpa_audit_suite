/// Workpaper Attachment Model
/// - Represents a single file attached to a workpaper.
/// - This is metadata only (name, size, storedPath, etc).
/// - The actual file copy/move is handled by your repository/storage layer.
library;

class WorkpaperAttachmentModel {
  final String id; // unique id for attachment
  final String name; // original filename displayed in UI
  final String storedPath; // where we saved it on disk (app-managed)
  final int sizeBytes; // size in bytes
  final String added; // yyyy-mm-dd

  const WorkpaperAttachmentModel({
    required this.id,
    required this.name,
    required this.storedPath,
    required this.sizeBytes,
    required this.added,
  });

  WorkpaperAttachmentModel copyWith({
    String? id,
    String? name,
    String? storedPath,
    int? sizeBytes,
    String? added,
  }) {
    return WorkpaperAttachmentModel(
      id: id ?? this.id,
      name: name ?? this.name,
      storedPath: storedPath ?? this.storedPath,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      added: added ?? this.added,
    );
  }

  factory WorkpaperAttachmentModel.fromJson(Map<String, dynamic> json) {
    return WorkpaperAttachmentModel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      storedPath: (json['storedPath'] ?? '').toString(),
      sizeBytes: _asInt(json['sizeBytes']),
      added: (json['added'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'storedPath': storedPath,
        'sizeBytes': sizeBytes,
        'added': added,
      };

  /// Convenience helpers (optional but useful)
  String get extension {
    final n = name.trim();
    final dot = n.lastIndexOf('.');
    if (dot <= 0 || dot == n.length - 1) return '';
    return n.substring(dot + 1).toLowerCase();
  }

  String get prettySize {
    final b = sizeBytes;
    if (b < 1024) return '$b B';
    final kb = b / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(2)} GB';
  }

  static int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.round();
    return int.tryParse(v.toString()) ?? 0;
  }
}