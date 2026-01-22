import 'package:flutter/material.dart';

import '../../../core/storage/local_store.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.store,
    required this.themeMode,
  });

  final LocalStore store;
  final ValueNotifier<ThemeMode> themeMode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: ListTile(
            title: const Text('Theme'),
            subtitle: const Text('Tap to toggle light/dark'),
            trailing: const Icon(Icons.brightness_6),
            onTap: () {
              final current = themeMode.value;
              themeMode.value =
                  (current == ThemeMode.dark) ? ThemeMode.light : ThemeMode.dark;
            },
          ),
        ),
      ),
    );
  }
}