import 'package:flutter/material.dart';
import '../../../core/storage/local_store.dart';

class EngagementDetailScreen extends StatelessWidget {
  const EngagementDetailScreen({
    super.key,
    required this.store,
    required this.themeMode,
    required this.engagementId,
  });

  final LocalStore store;
  final ValueNotifier<ThemeMode> themeMode;
  final String engagementId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Engagement Detail')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.assignment_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Engagement ID: $engagementId',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}