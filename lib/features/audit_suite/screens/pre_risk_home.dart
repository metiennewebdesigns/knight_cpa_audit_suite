import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/storage/local_store.dart';
import '../data/models/engagement_models.dart';
import '../data/models/repositories/engagements_repository.dart';
import '../data/models/repositories/clients_repository.dart';

class PreRiskHomeScreen extends StatefulWidget {
  const PreRiskHomeScreen({
    super.key,
    required this.store,
    required this.themeMode,
  });

  final LocalStore store;
  final ValueNotifier<ThemeMode> themeMode;

  @override
  State<PreRiskHomeScreen> createState() => _PreRiskHomeScreenState();
}

class _PreRiskHomeScreenState extends State<PreRiskHomeScreen> {
  late final EngagementsRepository _engRepo;
  late final ClientsRepository _clientsRepo;

  late Future<_Vm> _future;
  bool _busy = false;

  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _engRepo = EngagementsRepository(widget.store);
    _clientsRepo = ClientsRepository(widget.store);
    _future = _load();

    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<_Vm> _load() async {
    final engagements = await _engRepo.getEngagements();
    final clients = await _clientsRepo.getClients();

    final clientNameById = <String, String>{
      for (final c in clients) c.id: c.name,
    };

    return _Vm(engagements: engagements, clientNameById: clientNameById);
  }

  Future<void> _refresh() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _engRepo.clearCache();
      await _clientsRepo.clearCache();
      setState(() => _future = _load());
      await _future;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<EngagementModel> _filter(List<EngagementModel> list, Map<String, String> clientNameById) {
    if (_query.isEmpty) return list;
    return list.where((e) {
      final clientName = clientNameById[e.clientId] ?? e.clientId;
      final hay = '${e.title} ${e.status} ${e.updated} ${e.id} $clientName'.toLowerCase();
      return hay.contains(_query);
    }).toList();
  }

  Future<void> _openRisk(EngagementModel e) async {
    final changed = await context.push<bool>('/engagements/${e.id}/risk');
    if (changed == true) {
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pre-Risk Assessments'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _busy ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<_Vm>(
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
                    'Failed to load engagements.',
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

            final vm = snap.data!;
            final filtered = _filter(vm.engagements, vm.clientNameById);

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Search engagements…',
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

                if (vm.engagements.isEmpty)
                  const Center(child: Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Text('No engagements yet. Create one first.'),
                  ))
                else if (filtered.isEmpty)
                  const Center(child: Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Text('No results. Try a different search.'),
                  ))
                else
                  ...filtered.map((e) {
                    final clientName = vm.clientNameById[e.clientId] ?? e.clientId;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        onTap: () => _openRisk(e),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        leading: const Icon(Icons.shield_outlined),
                        title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('Client: $clientName • Status: ${e.status}'),
                        trailing: const Icon(Icons.chevron_right),
                      ),
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Vm {
  final List<EngagementModel> engagements;
  final Map<String, String> clientNameById;

  const _Vm({
    required this.engagements,
    required this.clientNameById,
  });
}