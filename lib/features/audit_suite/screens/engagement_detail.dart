import 'package:flutter/material.dart';

class EngagementDetailScreen extends StatelessWidget {
  const EngagementDetailScreen({
    super.key,
    required this.engagementId,
  });

  final String engagementId;

  @override
  Widget build(BuildContext context) {
    final data = _mock(engagementId);

    return Scaffold(
      appBar: AppBar(title: const Text('Engagement Detail')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _row('Engagement ID', engagementId),
          _row('Client', data['client']!),
          _row('Entity Type', data['entityType']!),
          _row('Jurisdiction', data['jurisdiction']!),
          _row('Tax Years', data['taxYears']!),
          _row('Status', data['status']!),
          _row('Created', data['created']!),
          _row('Last Updated', data['updated']!),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),
          const Text(
            'Next steps: workpapers, risk flags, audit packet',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Map<String, String> _mock(String id) {
    if (id == 'eng-1002') {
      return {
        'client': 'DSG Luxury Transportation',
        'entityType': 'LLC',
        'jurisdiction': 'Texas',
        'taxYears': '2023–2024',
        'status': 'Planning',
        'created': '2026-01-12',
        'updated': '2026-01-21',
      };
    }
    return {
      'client': 'The Goddess Collection',
      'entityType': 'LLC',
      'jurisdiction': 'Louisiana',
      'taxYears': '2024',
      'status': 'In Progress',
      'created': '2026-01-10',
      'updated': '2026-01-21',
    };
  }
}