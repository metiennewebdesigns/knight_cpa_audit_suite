import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/storage/local_store.dart';

import '../data/models/client_models.dart';
import '../data/models/repositories/clients_repository.dart';
import '../services/client_csv_importer.dart';
import '../services/client_meta.dart';


// ✅ use the FS facade (web-safe)
import '../services/engagement_detail_fs.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({
    super.key,
    required this.store,
    required this.themeMode,
  });

  final LocalStore store;
  final ValueNotifier<ThemeMode> themeMode;

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  late final ClientsRepository _clientsRepo;

  late Future<List<_ClientRowVm>> _future;
  bool _busy = false;

  final _searchCtrl = TextEditingController();

  bool get _canFile => !kIsWeb && widget.store.canUseFileSystem;
  String get _docsPath => widget.store.documentsPath ?? '';

  @override
  void initState() {
    super.initState();
    _clientsRepo = ClientsRepository(widget.store);
    _future = _load();

    _searchCtrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<List<_ClientRowVm>> _load() async {
    final list = await _clientsRepo.getClients();

    final out = <_ClientRowVm>[];
    for (final c in list) {
      final addr = await ClientMeta.readAddress(c.id);
      final a = _Addr.fromMeta(addr);

      final display = _displayLinesForClient(c, a);

      out.add(
        _ClientRowVm(
          client: c,
          addr: a,
          displayLine1: display.$1,
          displayLine2: display.$2,
        ),
      );
    }

    out.sort((a, b) => b.client.updated.compareTo(a.client.updated));
    return out;
  }

  (String, String) _displayLinesForClient(ClientModel c, _Addr a) {
    final fallback = c.location.trim();

    final hasStreet = a.streetLine.trim().isNotEmpty;
    final hasCityLine = a.cityLine.trim().isNotEmpty;

    if (!hasStreet) {
      final one = fallback.isNotEmpty ? fallback : (hasCityLine ? a.cityLine : '');
      return (one, '');
    }

    String line1 = a.streetLine;
    String line2 = hasCityLine ? a.cityLine : fallback;

    if (line2.trim().toLowerCase() == line1.trim().toLowerCase()) {
      line2 = '';
    }

    return (line1, line2);
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

  void _openClient(String id) {
    context.pushNamed('clientDetail', pathParameters: {'id': id});
  }

  // ✅ Write address meta ONLY on desktop (file system available)
  Future<void> _writeClientAddress(String clientId, _Addr address) async {
    if (!_canFile || _docsPath.trim().isEmpty) return;

    final metaDir = '$_docsPath/Auditron/ClientMeta';
    await ensureDir(metaDir);

    final fp = '$metaDir/$clientId.json';

    Map<String, dynamic> data = {};
    try {
      if (await fileExists(fp)) {
        final raw = await readTextFile(fp);
        if (raw.trim().isNotEmpty) data = jsonDecode(raw) as Map<String, dynamic>;
      }
    } catch (_) {
      data = {};
    }

    data['address'] = address.toJson();
    await writeTextFile(fp, jsonEncode(data));
  }

  Future<void> _createClient() async {
    if (_busy) return;

    final created = await showDialog<_CreateClientResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _CreateClientDialog(),
    );

    if (created == null) return;

    setState(() => _busy = true);
    try {
      final cityState = _cityState(created.city, created.state);

      final saved = await _clientsRepo.upsert(
        ClientModel(
          id: '',
          name: created.name.trim(),
          location: cityState,
          status: 'Active',
          updated: '',
          taxId: created.taxId.trim(),
          email: created.email.trim(),
          phone: created.phone.trim(),
        ),
      );

      await _writeClientAddress(
        saved.id,
        _Addr(
          line1: created.line1,
          line2: created.line2,
          city: created.city,
          state: created.state,
          zip: created.zip,
        ),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Client created ✅')));

      await _refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importClientsCsv() async {
    if (_busy) return;

    setState(() => _busy = true);
    try {
      final pick = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv'],
        withData: false,
      );

      if (pick == null || pick.files.isEmpty) return;
      final path = pick.files.first.path;
      if (path == null || path.trim().isEmpty) return;

      final csvText = await ClientCsvImporter.readFileText(path);
      final rows = ClientCsvImporter.parse(csvText);

      int imported = 0;
      int skipped = 0;

      for (final r in rows) {
        final name = r.name.trim();
        if (name.isEmpty) {
          skipped++;
          continue;
        }

        final cityState = _cityState(r.city, r.state);

        final saved = await _clientsRepo.upsert(
          ClientModel(
            id: '',
            name: name,
            location: cityState,
            status: 'Active',
            updated: '',
            taxId: '',
            email: '',
            phone: '',
          ),
        );

        await _writeClientAddress(
          saved.id,
          _Addr(
            line1: r.line1,
            line2: r.line2,
            city: r.city,
            state: r.state,
            zip: r.zip,
          ),
        );

        imported++;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV import complete ✅ Imported $imported • Skipped $skipped')),
      );

      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV import failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<_ClientRowVm> _applySearch(List<_ClientRowVm> list) {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return list;

    bool hit(_ClientRowVm vm) {
      final c = vm.client;
      final hay = [
        c.name,
        c.id,
        c.location,
        c.status,
        c.taxId,
        c.email,
        c.phone,
        vm.addr.streetLine,
        vm.addr.cityLine,
      ].join(' ').toLowerCase();

      return hay.contains(q);
    }

    return list.where(hit).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clients'),
        actions: [
          IconButton(
            tooltip: 'Import CSV',
            onPressed: _busy ? null : _importClientsCsv,
            icon: const Icon(Icons.upload_file),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _busy ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _createClient,
        icon: const Icon(Icons.add),
        label: const Text('Add Client'),
      ),
      body: FutureBuilder<List<_ClientRowVm>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasError) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const SizedBox(height: 40),
                const Icon(Icons.error_outline, size: 44),
                const SizedBox(height: 10),
                Text(
                  'Clients failed to load.',
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

          final all = snap.data ?? const <_ClientRowVm>[];
          final filtered = _applySearch(all);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            children: [
              if (!_canFile)
                Card(
                  color: cs.surfaceContainerHighest,
                  child: const ListTile(
                    leading: Icon(Icons.public),
                    title: Text('Web demo mode'),
                    subtitle: Text('Client address meta storage is disabled on web (contact fields still work).'),
                  ),
                ),
              if (!_canFile) const SizedBox(height: 12),
              TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Search clients (name, contact, status, id, address)…',
                  filled: true,
                  fillColor: cs.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide(color: cs.onSurface.withValues(alpha: 0.08)),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (filtered.isEmpty)
                _EmptyState(
                  title: all.isEmpty ? 'No clients yet' : 'No matches',
                  subtitle: all.isEmpty ? 'Create your first client to begin.' : 'Try a different search term.',
                )
              else
                ...filtered.map((vm) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ClientCard(
                        name: vm.client.name,
                        line1: vm.displayLine1,
                        line2: vm.displayLine2,
                        status: vm.client.status,
                        updated: _prettyMonth(vm.client.updated),
                        taxId: vm.client.taxId,
                        email: vm.client.email,
                        phone: vm.client.phone,
                        onTap: () => _openClient(vm.client.id),
                      ),
                    )),
            ],
          );
        },
      ),
    );
  }
}

/* ========================= View models ========================= */

class _ClientRowVm {
  final ClientModel client;
  final _Addr addr;
  final String displayLine1;
  final String displayLine2;

  const _ClientRowVm({
    required this.client,
    required this.addr,
    required this.displayLine1,
    required this.displayLine2,
  });
}

class _Addr {
  final String line1;
  final String line2;
  final String city;
  final String state;
  final String zip;

  const _Addr({
    required this.line1,
    required this.line2,
    required this.city,
    required this.state,
    required this.zip,
  });

  static _Addr fromMeta(Map<String, dynamic> meta) {
    final a = (meta['address'] is Map) ? (meta['address'] as Map) : meta;
    return _Addr(
      line1: (a['line1'] ?? '').toString().trim(),
      line2: (a['line2'] ?? '').toString().trim(),
      city: (a['city'] ?? '').toString().trim(),
      state: (a['state'] ?? '').toString().trim(),
      zip: (a['zip'] ?? '').toString().trim(),
    );
  }

  String get streetLine {
    final a = line1.trim();
    final b = line2.trim();
    if (a.isEmpty && b.isEmpty) return '';
    if (b.isEmpty) return a;
    if (a.isEmpty) return b;
    return '$a, $b';
  }

  String get cityLine {
    final c = city.trim();
    final s = state.trim().toUpperCase();
    final z = zip.trim();
    final left = [c, s].where((x) => x.isNotEmpty).join(', ');
    if (left.isEmpty && z.isEmpty) return '';
    if (left.isEmpty) return z;
    if (z.isEmpty) return left;
    return '$left $z';
  }

  Map<String, dynamic> toJson() => {
        'line1': line1.trim(),
        'line2': line2.trim(),
        'city': city.trim(),
        'state': state.trim(),
        'zip': zip.trim(),
      };
}

/* ========================= UI ========================= */

class _ClientCard extends StatelessWidget {
  const _ClientCard({
    required this.name,
    required this.line1,
    required this.line2,
    required this.status,
    required this.updated,
    required this.taxId,
    required this.email,
    required this.phone,
    required this.onTap,
  });

  final String name;
  final String line1;
  final String line2;
  final String status;
  final String updated;

  final String taxId;
  final String email;
  final String phone;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final chips = <Widget>[
  _Chip(text: 'Status: $status'),
  _Chip(text: 'Updated: $updated'),

  // ✅ Always show these so the UI change is visible immediately
  _Chip(text: 'TIN: ${taxId.trim().isEmpty ? "—" : taxId.trim()}'),
  _Chip(text: 'Email: ${email.trim().isEmpty ? "—" : email.trim()}'),
  _Chip(text: 'Phone: ${phone.trim().isEmpty ? "—" : phone.trim()}'),
];

    return Material(
      color: cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
                ),
                child: const Icon(Icons.apartment_outlined, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.15,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      line1,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.78),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    if (line2.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        line2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.72),
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: chips,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: cs.onSurface.withValues(alpha: 0.55)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: cs.surface,
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.10)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.onSurface.withValues(alpha: 0.72),
            ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.apartment_outlined, size: 48),
            const SizedBox(height: 10),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(subtitle, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

/* ========================= Create Client Dialog ========================= */

class _CreateClientDialog extends StatefulWidget {
  const _CreateClientDialog();

  @override
  State<_CreateClientDialog> createState() => _CreateClientDialogState();
}

class _CreateClientDialogState extends State<_CreateClientDialog> {
  final _nameCtrl = TextEditingController();
  final _line1Ctrl = TextEditingController();
  final _line2Ctrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _zipCtrl = TextEditingController();

  final _taxIdCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _line1Ctrl.dispose();
    _line2Ctrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _zipCtrl.dispose();
    _taxIdCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    final line1 = _line1Ctrl.text.trim();
    final city = _cityCtrl.text.trim();
    final state = _stateCtrl.text.trim();
    final zip = _zipCtrl.text.trim();

    if (name.isEmpty || line1.isEmpty || city.isEmpty || state.isEmpty || zip.isEmpty) return;

    Navigator.of(context).pop(
      _CreateClientResult(
        name: name,
        line1: line1,
        line2: _line2Ctrl.text.trim(),
        city: city,
        state: state,
        zip: zip,
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
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Client Name', border: OutlineInputBorder()),
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
                controller: _line1Ctrl,
                decoration: const InputDecoration(labelText: 'Address Line 1', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _line2Ctrl,
                decoration: const InputDecoration(labelText: 'Address Line 2 (optional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _cityCtrl,
                      decoration: const InputDecoration(labelText: 'City', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _stateCtrl,
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 2,
                      decoration: const InputDecoration(labelText: 'State', counterText: '', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _zipCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'ZIP', border: OutlineInputBorder()),
                    ),
                  ),
                ],
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

class _CreateClientResult {
  final String name;
  final String line1;
  final String line2;
  final String city;
  final String state;
  final String zip;

  final String taxId;
  final String email;
  final String phone;

  const _CreateClientResult({
    required this.name,
    required this.line1,
    required this.line2,
    required this.city,
    required this.state,
    required this.zip,
    required this.taxId,
    required this.email,
    required this.phone,
  });
}

/* ========================= Helpers ========================= */

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

String _cityState(String city, String state) {
  final c = city.trim();
  final s = state.trim().toUpperCase();
  if (c.isEmpty && s.isEmpty) return '';
  if (c.isEmpty) return s;
  if (s.isEmpty) return c;
  return '$c, $s';
}