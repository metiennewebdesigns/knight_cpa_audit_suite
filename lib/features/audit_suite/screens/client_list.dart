import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:knight_cpa_audit_suite/core/storage/local_store.dart';

class ClientsListScreen extends StatelessWidget {
  const ClientsListScreen({
    super.key,
    required this.store,
    required this.themeMode,
  });

  final LocalStore store;
  final ValueNotifier<ThemeMode> themeMode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clients'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: const Center(
        child: Text(
          'Clients Screen ✅\n\nNext: wire real client list',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}