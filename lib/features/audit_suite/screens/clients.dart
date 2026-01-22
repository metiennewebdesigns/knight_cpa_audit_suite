import 'package:flutter/material.dart';
import '../../../core/storage/local_store.dart';

class ClientsScreen extends StatelessWidget {
  const ClientsScreen({
    super.key,
    required this.store,
    required this.themeMode,
  });

  final LocalStore store;
  final ValueNotifier<ThemeMode> themeMode;

  @override
  Widget build(BuildContext context) {
    final clients = const [
      ('The Goddess Collection', 'Kenner, LA'),
      ('DSG Luxury Transportation', 'Dayton, TX'),
      ('Knight CPA Services', 'Kenner, LA'),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Clients')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: clients.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final (name, location) = clients[i];
          return ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            title: Text(name),
            subtitle: Text(location),
            leading: const Icon(Icons.business),
          );
        },
      ),
    );
  }
}