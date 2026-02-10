import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/storage/local_store.dart';


class LettersScreen extends StatelessWidget {
  const LettersScreen({
    super.key,
    required this.store,
    required this.themeMode,
    required this.engagementId,
  });

  final LocalStore store;
  final ValueNotifier<ThemeMode> themeMode;
  final String engagementId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Letters'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _LetterCard(
            icon: Icons.handshake_outlined,
            title: 'Engagement Letter',
            subtitle: 'AICPA-aligned engagement letter template (locked)',
            onTap: () => context.push('/engagements/$engagementId/letters/engagement'),
          ),
          const SizedBox(height: 12),
          _LetterCard(
            icon: Icons.playlist_add_check_outlined,
            title: 'PBC Request Letter',
            subtitle: 'Provided-By-Client request letter (locked)',
            onTap: () => context.push('/engagements/$engagementId/letters/pbc'),
          ),
          const SizedBox(height: 12),
          _LetterCard(
            icon: Icons.verified_user_outlined,
            title: 'Management Representation Letter',
            subtitle: 'AICPA-aligned management rep letter shell (locked)',
            onTap: () => context.push('/engagements/$engagementId/letters/mrl'),
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                'These templates are locked (read-only) for Phase 1.\n'
                'You can export to PDF. Editing/toggles come in Phase 2.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LetterCard extends StatelessWidget {
  const _LetterCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurface.withOpacity(0.70),
                          ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: cs.onSurface.withOpacity(0.55)),
            ],
          ),
        ),
      ),
    );
  }
}