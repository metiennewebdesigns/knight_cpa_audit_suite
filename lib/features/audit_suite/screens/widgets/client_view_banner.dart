import 'package:flutter/material.dart';

class ClientViewBanner extends StatelessWidget {
  const ClientViewBanner({
    super.key,
    required this.show,
    required this.message,
  });

  final bool show;
  final String message;

  @override
  Widget build(BuildContext context) {
    if (!show) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: cs.outlineVariant.withOpacity(0.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 🔒 Lock icon
            Icon(
              Icons.lock_outline,
              color: cs.primary,
            ),
            const SizedBox(width: 12),

            // 🧾 Message
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(width: 12),

            // 🏷️ Auditron logo (CORRECT PATH)
            Image.asset(
              'assets/branding/auditron_logo_dark.png',
              height: 28,
              fit: BoxFit.contain,
            ),
          ],
        ),
      ),
    );
  }
}