import 'package:flutter/material.dart';

import '../services/client_meta.dart';

class ClientAddressCard extends StatefulWidget {
  const ClientAddressCard({
    super.key,
    required this.clientId,
  });

  final String clientId;

  @override
  State<ClientAddressCard> createState() => _ClientAddressCardState();
}

class _ClientAddressCardState extends State<ClientAddressCard> {
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
    final a = await ClientMeta.readAddress(widget.clientId);

    _addr1Ctrl.text = a['address1'] ?? '';
    _addr2Ctrl.text = a['address2'] ?? '';
    _cityCtrl.text = a['city'] ?? '';
    _stateCtrl.text = a['state'] ?? '';
    _postalCtrl.text = a['postal'] ?? '';
    _countryCtrl.text = a['country'] ?? '';

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    await ClientMeta.saveAddress(
      clientId: widget.clientId,
      address1: _addr1Ctrl.text,
      address2: _addr2Ctrl.text,
      city: _cityCtrl.text,
      state: _stateCtrl.text,
      postal: _postalCtrl.text,
      country: _countryCtrl.text,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Client address saved ✅')),
    );
  }

  Future<void> _reset() async {
    if (_saving) return;
    setState(() => _saving = true);

    await ClientMeta.resetAddress(widget.clientId);
    await _load();

    if (!mounted) return;
    setState(() => _saving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Client address cleared ✅')),
    );
  }

  @override
  void dispose() {
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
            ? const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Client Address',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Used on exported PDFs for this client.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.70),
                        ),
                  ),
                  const SizedBox(height: 14),

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
                        label: const Text('Clear'),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}