import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class EngagementsListScreen extends StatelessWidget {
  const EngagementsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final engagements = const [
      {
        'id': 'eng-1001',
        'client': 'The Goddess Collection',
        'status': 'In Progress',
        'years': '2024',
      },
      {
        'id': 'eng-1002',
        'client': 'DSG Luxury Transportation',
        'status': 'Planning',
        'years': '2023–2024',
      },
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Engagements')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: engagements.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final e = engagements[i];
          return Card(
            child: ListTile(
              title: Text(e['client']!),
              subtitle: Text('Tax Years: ${e['years']}'),
              trailing: Text(e['status']!),
              onTap: () => context.push('/engagements/${e['id']}'),
            ),
          );
        },
      ),
    );
  }
}