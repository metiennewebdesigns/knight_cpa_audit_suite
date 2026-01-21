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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checklist'),
        actions: [
          IconButton(
            tooltip: 'Toggle theme',
            icon: Icon(themeMode.value == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () {
              themeMode.value =
                  themeMode.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
            },
          ),
        ],
      ),
      body: const Center(
        child: Text('Checklist ✅ (placeholder)'),
      ),
    );
  }
}