import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'trainer_profile_screens.dart';
import 'trainer_directory_screen.dart';
import 'workout_plans_screen.dart';

class CollaborationScreen extends StatefulWidget {
  const CollaborationScreen({super.key});

  @override
  State<CollaborationScreen> createState() => _CollaborationScreenState();
}

class _CollaborationScreenState extends State<CollaborationScreen> {
  final _searchController = TextEditingController();
  final _client = Supabase.instance.client;
  String? _role;
  List<Map<String, dynamic>> _connections = [];
  List<Map<String, dynamic>> _pendingTestimonials = [];
  List<Map<String, dynamic>> _results = [];
  bool _loading = true;
  bool _searching = false;
  bool _busy = false;
  String? _error;

  String get _userId => _client.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
      final role = values[0] as String?;
      final pending = role == 'trainer'
          ? await _client
                .from('trainer_testimonials')
                .select('id,rating,body,created_at')
                .eq('trainer_id', _userId)
                .eq('status', 'pending')
                .order('created_at', ascending: false)
          : const <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        _role = role;
        _connections = _maps(values[1]);
        _pendingTestimonials = _maps(pending);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Spoluprácu sa nepodarilo načítať.';
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _maps(Object? response) {
    if (response is! List) return [];
    return response
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<void> _search() async {
    final term = _searchController.text.trim();
    if (term.length < 2 || _searching) return;
    setState(() => _searching = true);
    try {
      final response = await _client.rpc(
        'search_collaboration_accounts',
        params: {'search_text': term},
      );
      if (!mounted) return;
      setState(() => _results = _maps(response));
    } catch (_) {
      if (mounted) _message('Vyhľadávanie účtov zlyhalo. Skúste to znova.');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _request(Map<String, dynamic> account) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _client.rpc(
        'request_trainer_client_connection',
        params: {'target_user_id': account['user_id']},
      );
      if (!mounted) return;
      _message('Žiadosť o spoluprácu bola odoslaná.');
      setState(() => _results = []);
      await _load();
    } catch (_) {
      if (mounted) _message('Žiadosť sa nepodarilo odoslať.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _respond(Map<String, dynamic> connection, bool accept) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _client.rpc(
        'respond_to_trainer_client_connection',
        params: {'connection_id': connection['id'], 'accept_request': accept},
      );
      if (mounted)
        _message(
          accept ? 'Spolupráca bola prijatá.' : 'Žiadosť bola zamietnutá.',
        );
      await _load();
    } catch (_) {
      if (mounted) _message('Žiadosť sa nepodarilo aktualizovať.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _reviewTrainer(Map<String, dynamic> connection) async {
    final formKey = GlobalKey<FormState>();
    final body = TextEditingController();
    var rating = 5;
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Ohodnotiť trénera'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  value: rating,
                  decoration: const InputDecoration(labelText: 'Hodnotenie'),
                  items: List.generate(5, (index) => index + 1)
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text('$value / 5 ★'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => rating = value ?? 5),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: body,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    labelText: 'Vaše skúsenosť',
                    helperText: 'Zverejnené hodnotenie bude označené „Klient“.',
                  ),
                  validator: (value) => (value?.trim().length ?? 0) < 10
                      ? 'Napíšte aspoň 10 znakov.'
                      : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Zrušiť'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('Odoslať'),
            ),
          ],
        ),
      ),
    );
    if (submitted != true) {
      body.dispose();
      return;
    }
    try {
      await _client.rpc(
        'submit_trainer_testimonial',
        params: {
          'target_connection_id': connection['id'],
          'testimonial_rating': rating,
          'testimonial_body': body.text.trim(),
        },
      );
      if (mounted) _message('Hodnotenie čaká na schválenie trénera.');
    } catch (_) {
      if (mounted)
        _message('Hodnotenie sa nepodarilo odoslať. Možno ste ho už poslali.');
    } finally {
      body.dispose();
      await _load();
    }
  }

  Future<void> _moderateTestimonial(
    Map<String, dynamic> testimonial,
    bool approve,
  ) async {
    try {
      await _client.rpc(
        'moderate_trainer_testimonial',
        params: {
          'target_testimonial_id': testimonial['id'],
          'approve': approve,
        },
      );
      if (mounted)
        _message(
          approve
              ? 'Hodnotenie bolo zverejnené.'
              : 'Hodnotenie bolo zamietnuté.',
        );
      await _load();
    } catch (_) {
      if (mounted) _message('Hodnotenie sa nepodarilo aktualizovať.');
    }
  }

  String _name(Map<String, dynamic> row) {
    final name =
        '${row['counterpart_first_name'] ?? ''} ${row['counterpart_last_name'] ?? ''}'
            .trim();
    return name.isEmpty
        ? (row['counterpart_email'] as String? ?? 'Používateľ')
        : name;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Tréner a klient'),
      actions: _role == 'trainer'
          ? [
              IconButton(
                tooltip: 'Upraviť verejný profil',
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => const TrainerProfileEditorScreen(),
                  ),
                ),
                icon: const Icon(Icons.edit_note_rounded),
              ),
              IconButton(
                tooltip: 'Zobraziť verejný profil',
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) =>
                        PublicTrainerProfileScreen(trainerId: _userId),
                  ),
                ),
                icon: const Icon(Icons.person_search_rounded),
              ),
            ]
          : null,
    ),
    body: SafeArea(
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _Failure(message: _error!, onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  _IntroCard(role: _role),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                      labelText: _role == 'trainer'
                          ? 'Nájsť klienta'
                          : 'Nájsť trénera',
                      hintText: 'Meno alebo e-mail',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: IconButton(
                        tooltip: 'Vyhľadať',
                        onPressed: _searching ? null : _search,
                        icon: _searching
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.arrow_forward_rounded),
                      ),
                    ),
                  ),
                  if (_role == 'client') ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => const TrainerDirectoryScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.star_rounded),
                        label: const Text('Prezrieť katalóg trénerov'),
                      ),
                    ),
                  ],
                  if (_results.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ..._results.map(
                      (account) => Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.person_outline_rounded),
                          ),
                          title: Text(
                            '${account['first_name'] ?? ''} ${account['last_name'] ?? ''}'
                                    .trim()
                                    .isEmpty
                                ? (account['email'] as String? ?? 'Používateľ')
                                : '${account['first_name'] ?? ''} ${account['last_name'] ?? ''}',
                          ),
                          subtitle: Text(account['email'] as String? ?? ''),
                          trailing: IconButton(
                            tooltip: 'Poslať žiadosť',
                            onPressed: _busy ? null : () => _request(account),
                            icon: const Icon(Icons.person_add_alt_1_rounded),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  const Text(
                    'MOJE SPOLUPRÁCE',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: .6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_connections.isEmpty)
                    const _InfoCard(
                      text:
                          'Zatiaľ nemáte žiadne žiadosti ani prepojených klientov.',
                    ),
                  ..._connections.map(_connectionTile),
                  if (_role == 'trainer') ...[
                    const SizedBox(height: 22),
                    const Text(
                      'ČAKAJÚCE HODNOTENIA',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        letterSpacing: .6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_pendingTestimonials.isEmpty)
                      const _InfoCard(
                        text: 'Nemáte žiadne nové hodnotenia na schválenie.',
                      ),
                    ..._pendingTestimonials.map(_pendingTestimonialTile),
                  ],
                ],
              ),
            ),
    ),
  );

  Widget _connectionTile(Map<String, dynamic> connection) {
    final status = connection['status'] as String? ?? 'pending';
    final incoming =
        connection['requester_id'] != _userId && status == 'pending';
    final accepted = status == 'accepted';
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: accepted ? const Color(0xFF142421) : null,
              child: Icon(
                accepted
                    ? Icons.fitness_center_rounded
                    : Icons.person_outline_rounded,
              ),
            ),
            title: Text(
              _name(connection),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              accepted
                  ? 'Prepojení klienti'
                  : status == 'pending'
                  ? (incoming ? 'Čaká na vašu odpoveď' : 'Čaká na odpoveď')
                  : 'Žiadosť bola zamietnutá',
            ),
            trailing: incoming
                ? Wrap(
                    spacing: 2,
                    children: [
                      IconButton(
                        tooltip: 'Prijať',
                        onPressed: _busy
                            ? null
                            : () => _respond(connection, true),
                        icon: const Icon(Icons.check_circle_outline_rounded),
                      ),
                      IconButton(
                        tooltip: 'Zamietnuť',
                        onPressed: _busy
                            ? null
                            : () => _respond(connection, false),
                        icon: const Icon(Icons.cancel_outlined),
                      ),
                    ],
                  )
                : accepted
                ? const Icon(Icons.chevron_right_rounded)
                : null,
            onTap: accepted
                ? () {
                    if (_role == 'client') {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => PublicTrainerProfileScreen(
                            trainerId: connection['trainer_id'] as String,
                          ),
                        ),
                      );
                    } else {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => WorkoutPlansScreen(
                            connection: connection,
                            currentRole: _role ?? 'client',
                          ),
                        ),
                      );
                    }
                  }
                : null,
          ),
          if (accepted && _role == 'client')
            Padding(
              padding: const EdgeInsets.only(left: 72, right: 12, bottom: 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _reviewTrainer(connection),
                  icon: const Icon(Icons.rate_review_outlined),
                  label: const Text('Ohodnotiť trénera'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _pendingTestimonialTile(Map<String, dynamic> testimonial) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(child: Icon(Icons.person_outline_rounded)),
              const SizedBox(width: 10),
              Text(
                'Klient  ·  ${testimonial['rating']}/5 ★',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(testimonial['body'] as String? ?? ''),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: () => _moderateTestimonial(testimonial, false),
                icon: const Icon(Icons.close_rounded),
                label: const Text('Zamietnuť'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _moderateTestimonial(testimonial, true),
                icon: const Icon(Icons.check_rounded),
                label: const Text('Schváliť'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.role});
  final String? role;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF142421),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFF2B4842)),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.handshake_outlined,
          color: Color(0xFF38D1BF),
          size: 28,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            role == 'trainer'
                ? 'Vyhľadajte klienta podľa mena alebo e-mailu. Po prijatí žiadosti môžete vytvárať tréningové plány.'
                : 'Vyhľadajte trénera a po prijatí žiadosti si pozrite svoje tréningové plány.',
            style: const TextStyle(color: Color(0xFFD1D9D2)),
          ),
        ),
      ],
    ),
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Text(text, style: const TextStyle(color: Color(0xFF9AACA7))),
    ),
  );
}

class _Failure extends StatelessWidget {
  const _Failure({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Skúsiť znova'),
          ),
        ],
      ),
    ),
  );
}
