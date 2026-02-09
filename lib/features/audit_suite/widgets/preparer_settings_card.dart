import 'package:flutter/material.dart';
import 'package:auditron/features/audit_suite/services/preparer_profile.dart';

class PreparerSettingsCard extends StatefulWidget {
  const PreparerSettingsCard({super.key});

  @override
  State<PreparerSettingsCard> createState() => _PreparerSettingsCardState();
}

class _PreparerSettingsCardState extends State<PreparerSettingsCard> {
  final _nameCtrl = TextEditingController();
  final _line2Ctrl = TextEditingController();

  // ✅ Address fields
  final _addr1Ctrl = TextEditingController();
  final _addr2Ctrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _postalCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final data = await PreparerProfile.read();

    _nameCtrl.text = data['name'] ?? 'Independent Auditor';
    _line2Ctrl.text = data['line2'] ?? '';

    _addr1Ctrl.text = data['address1'] ?? '';
    _addr2Ctrl.text = data['address2'] ?? '';
    _cityCtrl.text = data['city'] ?? '';
    _stateCtrl.text = data['state'] ?? '';
    _postalCtrl.text = data['postal'] ?? '';
    _countryCtrl.text = data['country'] ?? '';

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    await PreparerProfile.save(
      preparerName: _nameCtrl.text,
      preparerLine2: _line2Ctrl.text,
      preparerAddress1: _addr1Ctrl.text,
      preparerAddress2: _addr2Ctrl.text,
      preparerCity: _cityCtrl.text,
      preparerState: _stateCtrl.text,
      preparerPostal: _postalCtrl.text,
      preparerCountry: _countryCtrl.text,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Preparer info saved ✅')),
    );
  }

  Future<void> _reset() async {
    if (_saving) return;
    setState(() => _saving = true);

    await PreparerProfile.resetToDefault();
    await _load();

    if (!mounted) return;
    setState(() => _saving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reset to default ✅')),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _line2Ctrl.dispose();
    _addr1Ctrl.dispose();
    _addr2Ctrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _postalCtrl.dispose();
    _countryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const SizedBox(height: 90, child: Center(child: CircularProgressIndicator()))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PDF Preparer Information',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'This appears on exported PDFs as “Prepared by”.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.70),
                        ),
                  ),
                  const SizedBox(height: 14),

                  Text('Prepared by name', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Independent Auditor (or your firm name)',
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text('Optional line 2', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _line2Ctrl,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Optional: CPA firm tagline / license line',
                    ),
                  ),

                  // ✅ Address section
                  const SizedBox(height: 14),
                  Text('Address', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),

                  TextField(
                    controller: _addr1Ctrl,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Street address',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _addr2Ctrl,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Suite / Unit (optional)',
                    ),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _cityCtrl,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'City',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 110,
                        child: TextField(
                          controller: _stateCtrl,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'State',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _postalCtrl,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'ZIP / Postal',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _countryCtrl,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Country (optional)',
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(_saving ? 'Saving…' : 'Save'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: _saving ? null : _reset,
                        icon: const Icon(Icons.restart_alt),
                        label: const Text('Reset'),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}