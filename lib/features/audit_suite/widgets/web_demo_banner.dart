import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class WebDemoBanner extends StatelessWidget {
  const WebDemoBanner({
    super.key,
    this.message,
    this.compact = false,
  });

  final String? message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;

    return Card(
      color: cs.surfaceVariant,
      child: ListTile(
        dense: compact,
        leading: const Icon(Icons.public),
        title: const Text('Web demo mode'),
        subtitle: Text(
          message ??
              'Local filesystem features (exports, reveal folder, opening local files) are disabled on web.',
        ),
      ),
    );
  }
}