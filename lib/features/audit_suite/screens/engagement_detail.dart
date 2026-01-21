import 'package:flutter/material.dart';
import '../../../core/storage/local_store.dart';

class EngagementDetailScreen extends StatelessWidget {
  const EngagementDetailScreen({
    super.key,
    required this.id,
    required this.store,
    required this.themeMode,
  });

  final String id;
  final LocalStore store;
  final ValueNotifier<ThemeMode> themeMode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Engagement $id'),
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
      body: Center(
        child: Text('Engagement Detail ✅\n\nID: $id', textAlign: TextAlign.center),
      ),
    );
  }
}