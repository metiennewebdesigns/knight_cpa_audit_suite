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
    final isDark = themeMode.value == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Dark Mode'),
            value: isDark,
            onChanged: (val) {
              themeMode.value = val ? ThemeMode.dark : ThemeMode.light;
            },
          ),
          const Divider(),
          const ListTile(
            title: Text('Settings ✅ (placeholder)'),
            subtitle: Text('We’ll wire real settings later.'),
          ),
        ],
      ),
    );
  }
}