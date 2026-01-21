import 'package:flutter/material.dart';

import 'package:knight_cpa_audit_suite/core/storage/local_store.dart';

class ClientDetailScreen extends StatelessWidget {
  const ClientDetailScreen({
    super.key,
    required this.clientId,
    required this.store,
    required this.themeMode,
  });

  final String clientId;
  final LocalStore store;
  final ValueNotifier<ThemeMode> themeMode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Client Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Client ID',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  clientId,
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Next:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'We will replace this placeholder with real client data pulled from your seed JSON / LocalStore.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}