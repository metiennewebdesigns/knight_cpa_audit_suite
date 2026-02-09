import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/storage/local_store.dart';
import '../services/access_control.dart';
import '../services/auditron_data_reset.dart';
import '../widgets/preparer_settings_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.store,
    required this.themeMode,
  });

  final LocalStore store;
  final ValueNotifier<ThemeMode> themeMode;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _busy = false;
  bool _demoMode = false;
  AppRole _role = AppRole.owner;

  bool get _canResetLocal => !kIsWeb && widget.store.canUseFileSystem;

  @override
  void initState() {
    super.initState();
    _loadAccess();
  }

  Future<void> _loadAccess() async {
    final r = await AccessControl.getRole();
    final d = await AccessControl.isDemoMode();
    if (!mounted) return;
    setState(() {
      _role = r;
      _demoMode = d;
    });
  }

  Future<void> _setRole(AppRole r) async {
    setState(() => _busy = true);
    try {
      await AccessControl.setRole(r);
      if (!mounted) return;
      setState(() => _role = r);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Role set to ${AccessControl.roleLabel(r)} ✅')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setDemo(bool v) async {
    setState(() => _busy = true);
    try {
      await AccessControl.setDemoMode(v);
      if (!mounted) return;
      setState(() => _demoMode = v);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(v ? 'Demo Mode enabled ✅' : 'Demo Mode disabled ✅')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetLocalDemoData() async {
    if (_busy) return;

    if (!_canResetLocal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Local data reset is disabled on web demo.')),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dc) => AlertDialog(
        title: const Text('Reset local Auditron data?'),
        content: const Text(
          'This deletes the local Documents/Auditron folder (PBC, EvidenceVault, Ledger, exports, logs).\n\n'
          'Use this before giving a demo to someone else.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dc).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(dc).pop(true), child: const Text('Reset')),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await resetAuditronLocalData();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Local Auditron data reset ✅')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reset failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = widget.themeMode.value == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: cs.primary.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cs.onSurface.withOpacity(0.08)),
                    ),
                    child: const Icon(Icons.settings_outlined),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Auditron',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.2,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Configuration & preferences',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: cs.onSurface.withOpacity(0.70),
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          Card(
            child: SwitchListTile(
              value: isDark,
              onChanged: (v) => widget.themeMode.value = v ? ThemeMode.dark : ThemeMode.light,
              title: const Text('Dark mode'),
              secondary: const Icon(Icons.dark_mode_outlined),
            ),
          ),

          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Role & Permissions',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This controls what the UI allows (exports, evidence, quick actions).',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withOpacity(0.70),
                        ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<AppRole>(
                    value: _role,
                    items: AppRole.values
                        .map((r) => DropdownMenuItem(value: r, child: Text(AccessControl.roleLabel(r))))
                        .toList(),
                    onChanged: _busy ? null : (v) => _setRole(v ?? _role),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Current role',
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Demo Mode',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enable a safer environment for tests and demos. Use Reset before giving a demo link.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withOpacity(0.70),
                        ),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _demoMode,
                    onChanged: _busy ? null : _setDemo,
                    title: const Text('Enable Demo Mode'),
                    secondary: const Icon(Icons.science_outlined),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _busy ? null : _resetLocalDemoData,
                    icon: const Icon(Icons.restart_alt),
                    label: Text(_canResetLocal ? 'Reset Local Demo Data' : 'Reset disabled on web'),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          PreparerSettingsCard(),

          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'About',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                        ),
                  ),
                  const SizedBox(height: 8),
                  _InfoRow(label: 'Product', value: 'Auditron'),
                  const SizedBox(height: 6),
                  _InfoRow(label: 'Build', value: 'Phase 1 (MVP+)'),
                  const SizedBox(height: 6),
                  _InfoRow(label: 'Mode', value: _demoMode ? 'Demo' : 'Normal'),
                  const SizedBox(height: 6),
                  _InfoRow(label: 'Role', value: AccessControl.roleLabel(_role)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface.withOpacity(0.72),
                ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withOpacity(0.80),
                ),
          ),
        ),
      ],
    );
  }
}