import 'package:flutter/material.dart';

import '../../../core/storage/local_store.dart';

class ClientsScreen extends StatelessWidget {
  const ClientsScreen({
    super.key,
    required this.store,
  });

  final LocalStore store;

  @override
  Widget build(BuildContext context) {
    final items = const [
      'The Goddess Collection',
      'DSG Luxury Transportation',
      'Knight CPA Services',
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Clients')),
      body: ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          return ListTile(
            leading: const Icon(Icons.person),
            title: Text(items[i]),
            subtitle: const Text('Tap to open'),
            onTap: () {},
          );
        },
      ),
    );
  }
}