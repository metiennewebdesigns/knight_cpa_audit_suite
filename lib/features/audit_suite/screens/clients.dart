import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:knight_cpa_audit_suite/core/storage/local_store.dart';

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
      ('the-goddess-collection', 'The Goddess Collection', 'Kenner, LA'),
      ('dsg-luxury-transportation', 'DSG Luxury Transportation', 'Dayton, TX'),
      ('knight-cpa-services', 'Knight CPA Services', 'New Orleans, LA'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clients'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: clients.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final id = clients[i].$1;
          final name = clients[i].$2;
          final location = clients[i].$3;

          return ListTile(
            leading: const CircleAvatar(child: Icon(Icons.business_outlined)),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(location),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/clients/$id'),
          );
        },
      ),
    );
  }
}