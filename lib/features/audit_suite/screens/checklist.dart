import 'package:flutter/material.dart';
import '../../../core/storage/local_store.dart';

class ChecklistScreen extends StatelessWidget {
  const ChecklistScreen({
    super.key,
    required this.store,
    required this.themeMode,
  });

  final LocalStore store;
  final ValueNotifier<ThemeMode> themeMode;

  @override
  Widget build(BuildContext context) {
    final items = const [
      ('Engagement letter uploaded', true),
      ('Trial balance imported', true),
      ('Confirmations sent', false),
      ('Workpapers reviewed', false),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Checklist')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final (label, done) = items[i];
          return ListTile(
            title: Text(label),
            leading: Icon(done ? Icons.check_circle : Icons.radio_button_unchecked),
          );
        },
      ),
    );
  }
}