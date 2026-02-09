import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/models/workpaper_models.dart';
import '../services/local_file_actions.dart';

class AttachmentTile extends StatelessWidget {
  const AttachmentTile({
    super.key,
    required this.attachment,
    this.onDelete,
  });

  final WorkpaperAttachmentModel attachment;
  final VoidCallback? onDelete;

  String get _filePath => attachment.localPath;

  @override
  Widget build(BuildContext context) {
    final locked = onDelete == null;

    return Card(
      child: FutureBuilder<bool>(
        future: localFileExists(_filePath),
        builder: (context, snap) {
          final exists = snap.data == true;

          return ListTile(
            leading: const Icon(Icons.attachment_outlined),
            title: Text(
              attachment.name,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                exists ? _filePath : 'Missing file (or disabled on web)\n$_filePath',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            trailing: Wrap(
              spacing: 6,
              children: [
                IconButton(
                  tooltip: kIsWeb ? 'Disabled on web' : 'Open',
                  onPressed: (!kIsWeb && exists)
                      ? () async {
                          try {
                            await openLocalFile(_filePath);
                          } catch (_) {}
                        }
                      : null,
                  icon: const Icon(Icons.open_in_new),
                ),
                IconButton(
                  tooltip: locked ? 'Locked (finalized)' : 'Delete',
                  onPressed: locked ? null : onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            isThreeLine: true,
          );
        },
      ),
    );
  }
}