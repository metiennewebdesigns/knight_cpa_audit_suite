import 'package:flutter/material.dart';

import '../../../core/storage/local_store.dart';

class EngagementDetailScreen extends StatelessWidget {
  const EngagementDetailScreen({
    super.key,
    required this.store,
    required this.engagementId,
  });

  final LocalStore store;
  final String engagementId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Engagement Detail'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Engagement ID: $engagementId',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text('This is a placeholder details page.'),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}