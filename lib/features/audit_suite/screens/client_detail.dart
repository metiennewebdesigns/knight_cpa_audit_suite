import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/storage/local_store.dart';

import '../data/models/client_models.dart';
import '../data/models/repositories/clients_repository.dart';

import '../widgets/client_address_card.dart';

class ClientDetailScreen extends StatefulWidget {
  const ClientDetailScreen({
    super.key,
    required this.store,
    required this.themeMode,
    required this.clientId,
  });

  final LocalStore store;
  final ValueNotifier<ThemeMode> themeMode;
  final String clientId;

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  late final ClientsRepository _clientsRepo;

  late Future<_Vm> _future;
  bool _busy = false;
  bool _changed = false;

  // Editors
  final _nameCtrl = TextEditingController();
  final _taxIdCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  ClientModel? _loaded;
  bool _seeded = false;

  // Seeds for dirty tracking
  String _seedName = '';
  String _seedTaxId = '';
  String _seedEmail = '';
  String _seedPhone = '';

  bool get _isDirty {
    if (!_seeded || _loaded == null) return false;
    return _nameCtrl.text.trim() != _seedName ||
        _taxIdCtrl.text.trim() != _seedTaxId ||
        _emailCtrl.text.trim() != _seedEmail ||
        _phoneCtrl.text.trim() != _seedPhone;
  }

  @override
  void initState() {
    super.initState();
    _clientsRepo = ClientsRepository(widget.store);
    _future = _load();

    void listen() {
      if (!_seeded) return;
      if (mounted) setState(() {});
    }

    _nameCtrl.addListener(listen);
    _taxIdCtrl.addListener(listen);
    _emailCtrl.addListener(listen);
    _phoneCtrl.addListener(listen);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _taxIdCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _seedFrom(ClientModel c) {
    _seeded = false;

    _loaded = c;

    _seedName = c.name.trim();
    _seedTaxId = c.taxId.trim();
    _seedEmail = c.email.trim();
    _seedPhone = c.phone.trim();

    _nameCtrl.text = _seedName;
    _taxIdCtrl.text = _seedTaxId;
    _emailCtrl.text = _seedEmail;
    _phoneCtrl.text = _seedPhone;

    _seeded = true;
  }

  Future<_Vm> _load() async {
    final c = await _clientsRepo.getById(widget.clientId);
    if (c == null) {
      throw StateError('Client not found: ${widget.clientId}');
    }

    _seedFrom(c);
    return _Vm(client: c);
  }

  Future<void> _refresh() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _clientsRepo.clearCache();
      setState(() => _future = _load());
      await _future;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirmDiscardIfDirty() async {
    if (!_isDirty) return true;

    final discard = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dc) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('You have unsaved edits. If you leave now, they will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dc).pop(false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dc).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    return discard == true;
  }

  Future<void> _save() async {
    if (_busy) return;

    final base = _loaded;
    if (base == null) return;

    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Client name is required')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final saved = await _clientsRepo.upsert(
        base.copyWith(
          name: name,
          taxId: _taxIdCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          updated: '', // repo usually sets this
        ),
      );

      _changed = true;
      _seedFrom(saved);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Client saved ✅')),
      );

      await _refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return WillPopScope(
      onWillPop: () async {
        final ok = await _confirmDiscardIfDirty();
        if (!ok) return false;
        context.pop(_changed);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              const Text('Client'),
              if (_isDirty && !_busy) ...[
                const SizedBox(width: 10),
                _Pill(
                  text: 'Unsaved',
                  bg: cs.tertiaryContainer,
                  border: cs.tertiary.withValues(alpha: 0.45),
                ),
              ],
            ],
          ),
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final ok = await _confirmDiscardIfDirty();
              if (!ok) return;
              if (!mounted) return;
              context.pop(_changed);
            },
          ),
          actions: [
            IconButton(
              tooltip: 'Save',
              onPressed: (_busy || !_isDirty) ? null : _save,
              icon: const Icon(Icons.save_outlined),
            ),
            IconButton(
              tooltip: 'Refresh',
              onPressed: _busy ? null : _refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: FutureBuilder<_Vm>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return _ErrorState(
                title: 'Failed to load client',
                message: snap.error.toString(),
                onRetry: _busy ? null : _refresh,
              );
            }

            final vm = snap.data!;
            final c = vm.client;

            return AbsorbPointer(
              absorbing: _busy,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                children: [
                  _HeaderCard(
                    icon: Icons.apartment_outlined,
                    title: c.name,
                    subtitle: 'Client ID: ${c.id} • Updated ${c.updated.isEmpty ? "—" : c.updated}',
                    trailing: _Pill(
                      text: 'Client',
                      bg: cs.primary.withValues(alpha: 0.14),
                      border: cs.primary.withValues(alpha: 0.35),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Client Details',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.15,
                                ),
                          ),
                          const SizedBox(height: 12),

                          Text('Name', style: Theme.of(context).textTheme.labelLarge),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _nameCtrl,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: 'Enter client name',
                            ),
                          ),

                          const SizedBox(height: 12),
                          Text('Tax ID / EIN', style: Theme.of(context).textTheme.labelLarge),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _taxIdCtrl,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: 'Optional',
                            ),
                          ),

                          const SizedBox(height: 12),
                          Text('Email', style: Theme.of(context).textTheme.labelLarge),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: 'Optional',
                            ),
                          ),

                          const SizedBox(height: 12),
                          Text('Phone', style: Theme.of(context).textTheme.labelLarge),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: 'Optional',
                            ),
                          ),

                          const SizedBox(height: 14),
                          FilledButton.icon(
                            onPressed: (_busy || !_isDirty) ? null : _save,
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('Save'),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ✅ Client Address (stored in /Auditron/ClientMeta/<clientId>.json)
                  ClientAddressCard(clientId: widget.clientId),

                  const SizedBox(height: 12),

                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Client address is used on exported PDFs for this client. '
                              'This is stored as metadata (Phase 1) so it won’t break your data models.',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: cs.onSurface.withValues(alpha: 0.70),
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Vm {
  final ClientModel client;
  const _Vm({required this.client});
}

/* ======================= UI helpers ======================= */

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: cs.primary.withValues(alpha: 0.14),
                border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
              ),
              child: Icon(icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.70),
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.text,
    required this.bg,
    required this.border,
  });

  final String text;
  final Color bg;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: bg,
        border: Border.all(color: border),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 60),
        const Icon(Icons.error_outline, size: 44),
        const SizedBox(height: 10),
        Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(message, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Try again'),
        ),
      ],
    );
  }
}