// lib/features/audit_suite/widgets/web_demo_banner.dart

import 'package:flutter/material.dart';

class WebDemoBanner extends StatelessWidget {
  const WebDemoBanner({
    super.key,
    required this.show,
    this.message,
  });

  final bool show;
  final String? message;

  @override
  Widget build(BuildContext context) {
    if (!show) return const SizedBox.shrink();

    return Card(
      child: ListTile(
        leading: const Icon(Icons.public),
        title: const Text('Web demo mode'),
        subtitle: Text(
          message ??
              'File-backed features are disabled on web (exports, portal logs, PIN storage).',
        ),
      ),
    );
  }
}