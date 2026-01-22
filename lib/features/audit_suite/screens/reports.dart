import 'package:flutter/material.dart';

import '../../../core/storage/local_store.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({
    super.key,
    required this.store,
  });

  final LocalStore store;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: const Center(
        child: Text('Reports placeholder'),
      ),
    );
  }
}