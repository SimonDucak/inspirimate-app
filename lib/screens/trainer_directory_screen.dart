import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'trainer_profile_screens.dart';

class TrainerDirectoryScreen extends StatefulWidget {
  const TrainerDirectoryScreen({super.key});

  @override
  State<TrainerDirectoryScreen> createState() => _TrainerDirectoryScreenState();
}

class _TrainerDirectoryScreenState extends State<TrainerDirectoryScreen> {
  static const _pageSize = 20;
  final _client = Supabase.instance.client;
  final _searchController = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _trainers = [];
  int _offset = 0;
  int _searchVersion = 0;
  bool _loading = true;
  bool _loadingMore = false;
  String? _requestingTrainerId;
  final Set<String> _requestedTrainerIds = {};
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _maps(Object? value) => value is List
      ? value.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList()
      : [];

  Future<void> _load({required bool reset}) async {
    if (!reset && (_loadingMore || !_hasMore)) return;
    final version = reset ? ++_searchVersion : _searchVersion;
    final offset = reset ? 0 : _offset;
    setState(() {
      if (reset) {
        _loading = true;
        _error = null;
      } else {
        _loadingMore = true;
      }
    });
    try {
      final response = await _client.rpc(
        'search_trainer_directory',
        params: {
          'search_email': _searchController.text.trim(),
          'page_offset': offset,
          'page_size': _pageSize,
        },
      );
      if (!mounted || version != _searchVersion) return;
      final rows = _maps(response);
      setState(() {
        _trainers = reset ? rows : [..._trainers, ...rows];
        _offset = offset + rows.length;
        _hasMore = rows.length == _pageSize;
        _loading = false;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted || version != _searchVersion) return;
      setState(() {
        _error = 'Adresár trénerov sa nepodarilo načítať.';
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _load(reset: true));
  }

  String _name(Map<String, dynamic> trainer) {
    final name = '${trainer['first_name'] ?? ''} ${trainer['last_name'] ?? ''}'.trim();
    return name.isEmpty ? 'Tréner' : name;
  }

  Future<void> _request(Map<String, dynamic> trainer) async {
    final trainerId = trainer['trainer_id'] as String;
    if (_requestingTrainerId != null || _requestedTrainerIds.contains(trainerId)) return;
    setState(() => _requestingTrainerId = trainerId);
    try {
      await _client.rpc('request_trainer_client_connection', params: {
        'target_user_id': trainerId,
      });
      if (!mounted) return;
      setState(() => _requestedTrainerIds.add(trainerId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Žiadosť o spoluprácu bola odoslaná.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Žiadosť sa nepodarilo odoslať. Možno už existuje.')),
      );
    } finally {
      if (mounted) setState(() => _requestingTrainerId = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Nájsť trénera')),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Hľadať podľa e-mailu',
                    hintText: 'Zadajte celý e-mail alebo jeho časť',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: IconButton(
                      tooltip: 'Vymazať vyhľadávanie',
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Zoradené podľa priemerného hodnotenia'),
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_error!, textAlign: TextAlign.center),
                                const SizedBox(height: 12),
                                FilledButton.icon(
                                  onPressed: () => _load(reset: true),
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Skúsiť znova'),
                                ),
                              ],
                            ),
                          )
                        : _trainers.isEmpty
                            ? const Center(child: Text('Nenašli sa tréneri.'))
                            : NotificationListener<ScrollNotification>(
                                onNotification: (notification) {
                                  if (notification.metrics.extentAfter < 300) {
                                    _load(reset: false);
                                  }
                                  return false;
                                },
                                child: ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                                  itemCount: _trainers.length + (_hasMore ? 1 : 0),
                                  itemBuilder: (context, index) {
                                    if (index == _trainers.length) {
                                      return Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Center(
                                          child: _loadingMore
                                              ? const CircularProgressIndicator()
                                              : TextButton(
                                                  onPressed: () => _load(reset: false),
                                                  child: const Text('Načítať ďalších'),
                                                ),
                                        ),
                                      );
                                    }
                                    final trainer = _trainers[index];
                                    final rating = trainer['average_rating'];
                                    final count = trainer['rating_count'] ?? 0;
                                    return Card(
                                      child: ListTile(
                                        leading: const CircleAvatar(
                                          child: Icon(Icons.fitness_center_rounded),
                                        ),
                                        title: Text(_name(trainer)),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            if ((trainer['headline'] as String? ?? '').isNotEmpty)
                                              Text(trainer['headline'] as String),
                                            Text(rating == null
                                                ? 'Zatiaľ bez hodnotení'
                                                : '★ ${double.parse(rating.toString()).toStringAsFixed(1)}  ·  $count hodnotení'),
                                          ],
                                        ),
                                        isThreeLine: (trainer['headline'] as String? ?? '').isNotEmpty,
                                        trailing: _requestedTrainerIds.contains(
                                                  trainer['trainer_id'],
                                                )
                                            ? const Icon(Icons.check_circle_outline_rounded)
                                            : IconButton(
                                                tooltip: 'Požiadať o spoluprácu',
                                                onPressed: _requestingTrainerId == null
                                                    ? () => _request(trainer)
                                                    : null,
                                                icon: _requestingTrainerId ==
                                                        trainer['trainer_id']
                                                    ? const SizedBox.square(
                                                        dimension: 20,
                                                        child: CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                        ),
                                                      )
                                                    : const Icon(
                                                        Icons.person_add_alt_1_rounded,
                                                      ),
                                              ),
                                        onTap: () => Navigator.of(context).push<void>(
                                          MaterialPageRoute(
                                            builder: (_) => PublicTrainerProfileScreen(
                                              trainerId: trainer['trainer_id'] as String,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
              ),
            ],
          ),
        ),
      );
}
