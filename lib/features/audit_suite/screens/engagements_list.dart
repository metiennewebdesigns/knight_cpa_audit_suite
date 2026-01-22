import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/storage/local_store.dart';

class EngagementsListScreen extends StatelessWidget {
  const EngagementsListScreen({
    super.key,
    required this.store,
  });

  final LocalStore store;

  @override
  Widget build(BuildContext context) {
    final engagements = const [
      _Eng(id: 'eng-1001', name: '2025 Tax Return', client: 'The Goddess Collection'),
      _Eng(id: 'eng-1002', name: 'Audit - Q4 Review', client: 'DSG Luxury Transportation'),
      _Eng(id: 'eng-1003', name: 'Bookkeeping Cleanup', client: 'Knight CPA Services'),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Engagements')),
      body: ListView.separated(
        itemCount: engagements.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final e = engagements[i];
          return ListTile(
            leading: const Icon(Icons.work),
            title: Text(e.name),
            subtitle: Text(e.client),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/engagements/${e.id}'),
          );
        },
      ),
    );
  }
}

class _Eng {
  const _Eng({required this.id, required this.name, required this.client});
  final String id;
  final String name;
  final String client;
}