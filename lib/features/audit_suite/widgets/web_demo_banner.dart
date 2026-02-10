import 'package:flutter/material.dart';

class WebDemoBanner extends StatelessWidget {
  const WebDemoBanner({
    super.key,
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      color: cs.surfaceContainerHighest,
      child: ListTile(
        leading: const Icon(Icons.public),
        title: const Text('Web demo mode'),
        subtitle: Text(message),
      ),
    );
  }
}