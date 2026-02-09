import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/storage/local_store.dart';
import '../data/models/client_models.dart';
import '../data/models/repositories/clients_repository.dart';

class ClientListScreen extends StatefulWidget {
  const ClientListScreen({
    super.key,
    required this.store,
    required this.themeMode,
  });

  final LocalStore store;
  final ValueNotifier<ThemeMode> themeMode;

  @override
  State<ClientListScreen> createState() => _ClientListScreenState();
}

class _ClientListScreenState extends State<ClientListScreen> {
  late final ClientsRepository _repo;

  final _searchCtrl = TextEditingController();
  String _query = '';

  bool _busy = false;
  late Future<List<ClientModel>> _future;

  @override
  void initState() {
    super.initState();
    _repo = ClientsRepository(widget.store);
    _future = _repo.getClients();

    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _repo.clearCache();
      setState(() => _future = _repo.getClients());
      await _future;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<ClientModel> _applyFilter(List<ClientModel> list) {
    if (_query.isEmpty) return list;
    return list.where((c) {
      final hay = [
        c.name,
        c.location,
        c.status,
        c.updated,
        c.id,
        c.taxId,
        c.email,
        c.phone,
      ].join(' ').toLowerCase();
      return hay.contains(_query);
    }).toList();
  }

  Future<void> _openClient(String id) async {
    final changed = await context.push<bool>('/clients/$id');
    if (changed == true) await _refresh();
  }

  Future<void> _createClient() async {
    if (_busy) return;

    final created = await showDialog<ClientModel>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _CreateClientDialog(),
    );

    if (created == null) return;

    setState(() => _busy = true);
    try {
      await _repo.upsert(created);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Client created ✅')),
      );
      await _refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clients (Legacy List)'),
        actions: [
          IconButton(
            tooltip: 'Create client',
            onPressed: _busy ? null : _createClient,
            icon: const Icon(Icons.add),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _busy ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<ClientModel>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snap.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  const SizedBox(height: 60),
                  const Icon(Icons.error_outline, size: 44),
                  const SizedBox(height: 10),
                  Text(
                    'Failed to load clients.',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snap.error.toString(),
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _busy ? null : _refresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try again'),
                  ),
                ],
              );
            }

            final all = snap.data ?? const <ClientModel>[];
            final filtered = _applyFilter(all);

            return AbsorbPointer(
              absorbing: _busy,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                children: [
                  TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Search clients…',
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear',
                              onPressed: () {
                                _searchCtrl.clear();
                                FocusScope.of(context).unfocus();
                              },
                              icon: const Icon(Icons.close),
                            ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (filtered.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 60),
                      child: Center(child: Text('No clients found')),
                    )
                  else
                    ...filtered.map((c) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          onTap: () => _openClient(c.id),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          tileColor: cs.surfaceContainerHighest,
                          leading: const Icon(Icons.apartment_outlined),
                          title: Text(
                            c.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _Chip(label: c.location),
                                _Chip(label: 'Status: ${c.status}'),
                                _Chip(label: 'Updated: ${_prettyMonth(c.updated)}'),
                                _Chip(label: 'TIN: ${c.taxId.trim().isEmpty ? "—" : c.taxId.trim()}'),
                                _Chip(label: 'Email: ${c.email.trim().isEmpty ? "—" : c.email.trim()}'),
                                _Chip(label: 'Phone: ${c.phone.trim().isEmpty ? "—" : c.phone.trim()}'),
                              ],
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          isThreeLine: true,
                        ),
                      );
                    }),
                ],
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _createClient,
        icon: const Icon(Icons.add),
        label: const Text('Create Client'),
      ),
    );
  }
}

class _CreateClientDialog extends StatefulWidget {
  const _CreateClientDialog();

  @override
  State<_CreateClientDialog> createState() => _CreateClientDialogState();
}

class _CreateClientDialogState extends State<_CreateClientDialog> {
  final _nameCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();

  final _taxIdCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  static const _statuses = ['Active', 'Inactive'];
  String _status = 'Active';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _locationCtrl.dispose();
    _taxIdCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    final location = _locationCtrl.text.trim();
    if (name.isEmpty || location.isEmpty) return;

    Navigator.of(context).pop(
      ClientModel(
        id: '',
        name: name,
        location: location,
        status: _status,
        updated: '',
        taxId: _taxIdCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Client'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Client Name', border: OutlineInputBorder()),
                autofocus: true,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _taxIdCtrl,
                decoration: const InputDecoration(labelText: 'Tax ID / EIN (optional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email (optional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone (optional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _locationCtrl,
                decoration: const InputDecoration(labelText: 'Location', hintText: 'e.g., Kenner, LA', border: OutlineInputBorder()),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _status,
                items: _statuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setState(() => _status = v ?? _status),
                decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Create')),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.35)),
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

String _prettyMonth(String iso) {
  final s = iso.trim();
  if (s.isEmpty || s.length < 7) return s.isEmpty ? '—' : s;
  final y = s.substring(0, 4);
  final m = s.substring(5, 7);
  const months = {
    '01': 'Jan',
    '02': 'Feb',
    '03': 'Mar',
    '04': 'Apr',
    '05': 'May',
    '06': 'Jun',
    '07': 'Jul',
    '08': 'Aug',
    '09': 'Sep',
    '10': 'Oct',
    '11': 'Nov',
    '12': 'Dec',
  };
  return '${months[m] ?? m} $y';
}