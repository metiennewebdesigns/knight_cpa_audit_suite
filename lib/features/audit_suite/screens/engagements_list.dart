import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/storage/local_store.dart';

class EngagementsListScreen extends StatelessWidget {
  const EngagementsListScreen({
    super.key,
    required this.store,
    required this.themeMode,
  });

  final LocalStore store;
  final ValueNotifier<ThemeMode> themeMode;

  @override
  Widget build(BuildContext context) {
    final engagements = const [
      ('eng-1001', 'FY 2025 Audit - The Goddess Collection'),
      ('eng-1002', 'FY 2025 Review - DSG Luxury Transportation'),
      ('eng-1003', 'Compilation - Knight CPA Services'),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Engagements')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: engagements.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final (id, title) = engagements[i];
          return ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            leading: const Icon(Icons.work_outline),
            title: Text(title),
            subtitle: Text(id),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/engagements/$id'),
          );
        },
      ),
    );
  }
}