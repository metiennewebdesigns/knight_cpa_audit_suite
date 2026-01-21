import 'package:flutter/material.dart';
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
    final items = const ['E-1001', 'E-1002', 'E-1003'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Engagements'),
        actions: [
          IconButton(
            tooltip: 'Toggle theme',
            icon: Icon(
              themeMode.value == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode,
            ),
            onPressed: () {
              themeMode.value =
                  themeMode.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
            },
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, i) {
          final id = items[i];
          return ListTile(
            title: Text('Engagement $id'),
            subtitle: const Text('Tap to open details'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).pushNamed('/engagements/$id'),
          );
        },
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemCount: items.length,
      ),
    );
  }
}