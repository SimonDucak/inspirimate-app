import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'trainer_directory_screen.dart';
import 'workout_plans_screen.dart';

class ClientWorkoutsScreen extends StatefulWidget {
  const ClientWorkoutsScreen({super.key});

  @override
  State<ClientWorkoutsScreen> createState() => _ClientWorkoutsScreenState();
}

class _ClientWorkoutsScreenState extends State<ClientWorkoutsScreen> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _connections = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<Map<String, dynamic>> _maps(Object? value) => value is List
      ? value
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList()
      : [];

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final values = await Future.wait<Object?>([
        _client.rpc('current_account_role'),
        _client.rpc('list_trainer_client_connections'),
      ]);
      if (!mounted) return;
      final role = values[0] as String?;
      setState(() {
        _connections = role == 'client'
            ? _maps(values[1])
                  .where((connection) => connection['status'] == 'accepted')
                  .toList()
            : [];
        _error = role == 'client' ? null : 'Táto sekcia je určená klientom.';
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Tréningy sa nepodarilo načítať.';
        _loading = false;
      });
    }
  }

  String _trainerName(Map<String, dynamic> connection) {
    final name =
        '${connection['counterpart_first_name'] ?? ''} ${connection['counterpart_last_name'] ?? ''}'
            .trim();
    return name.isEmpty
        ? connection['counterpart_email'] as String? ?? 'Môj tréner'
        : name;
  }

  Future<void> _openPlans(Map<String, dynamic> connection) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            WorkoutPlansScreen(connection: connection, currentRole: 'client'),
      ),
    );
  }

  Future<void> _openPersonalPlan() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => const WorkoutPlansScreen(currentRole: 'client'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Moje tréningy'),
      actions: [
        IconButton(
          tooltip: 'Nájsť trénera',
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute(builder: (_) => const TrainerDirectoryScreen()),
          ),
          icon: const Icon(Icons.person_search_rounded),
        ),
        IconButton(
          tooltip: 'Obnoviť',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: SafeArea(
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Skúsiť znova'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.person_outline_rounded),
                      ),
                      title: const Text('Môj vlastný plán'),
                      subtitle: const Text(
                        'Vytvorte si plán a zaznamenávajte tréningy bez trénera',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: _openPersonalPlan,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Plány od vašich trénerov',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  if (_connections.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            const Icon(Icons.fitness_center, size: 34),
                            const SizedBox(height: 10),
                            const Text(
                              'Zatiaľ nemáte prepojeného trénera. Svoj vlastný tréningový plán môžete vytvoriť vyššie.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () => Navigator.of(context).push<void>(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const TrainerDirectoryScreen(),
                                ),
                              ),
                              icon: const Icon(Icons.people_outline),
                              label: const Text('Nájsť trénera'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ..._connections.map(
                    (connection) => Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.fitness_center_rounded),
                        ),
                        title: Text(_trainerName(connection)),
                        subtitle: const Text('Zobraziť tréningové plány'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _openPlans(connection),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    ),
  );
}
