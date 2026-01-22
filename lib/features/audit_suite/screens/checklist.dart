import 'package:flutter/material.dart';

import '../../../core/storage/local_store.dart';

class ChecklistScreen extends StatelessWidget {
  const ChecklistScreen({
    super.key,
    required this.store,
  });

  final LocalStore store;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checklist')),
      body: ListView(
        children: const [
          CheckboxListTile(value: true, onChanged: null, title: Text('Engagement setup complete')),
          CheckboxListTile(value: false, onChanged: null, title: Text('Client confirms scope')),
          CheckboxListTile(value: false, onChanged: null, title: Text('Evidence uploaded')),
        ],
      ),
    );
  }
}