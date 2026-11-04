import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TrainerProfileEditorScreen extends StatefulWidget {
  const TrainerProfileEditorScreen({super.key});

  @override
  State<TrainerProfileEditorScreen> createState() =>
      _TrainerProfileEditorScreenState();
}

class _TrainerProfileEditorScreenState extends State<TrainerProfileEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _headline = TextEditingController();
  final _bio = TextEditingController();
  final _specialties = TextEditingController();
  final _years = TextEditingController();
  final _client = Supabase.instance.client;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _headline.dispose();
    _bio.dispose();
    _specialties.dispose();
    _years.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final row = await _client
          .from('trainer_profiles')
          .select('headline,bio,specialties,years_experience')
          .eq('trainer_id', _client.auth.currentUser!.id)
          .maybeSingle();
      if (row != null) {
        _headline.text = row['headline'] as String? ?? '';
        _bio.text = row['bio'] as String? ?? '';
        _specialties.text = (row['specialties'] as List? ?? []).join(', ');
        _years.text = row['years_experience']?.toString() ?? '';
      }
    } catch (_) {
      _message('Profil trénera sa nepodarilo načítať.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    try {
      await _client.from('trainer_profiles').upsert({
        'trainer_id': _client.auth.currentUser!.id,
        'headline': _headline.text.trim(),
        'bio': _bio.text.trim(),
        'specialties': _specialties.text
            .split(',')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList(),
        'years_experience': _years.text.trim().isEmpty
            ? null
            : int.parse(_years.text.trim()),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      if (mounted) _message('Profil trénera bol uložený.');
    } catch (_) {
      if (mounted) _message('Profil sa nepodarilo uložiť. Skontrolujte údaje.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String? _bounded(String? value, int max, String label) {
    final text = value?.trim() ?? '';
    if (text.length > max) return 'Najviac $max znakov.';
    if (text.isEmpty && label == 'Titulok') return 'Vyplňte krátky titulok.';
    return null;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Profil trénera')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Text(
                      'Predstavte svoje služby klientom. Verejné hodnotenia zobrazujú iba meno „Klient“.',
                    ),
                    const SizedBox(height: 20),
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _headline,
                            maxLength: 120,
                            decoration: const InputDecoration(
                              labelText: 'Titulok',
                              hintText: 'Napríklad osobný tréner a výživový poradca',
                            ),
                            validator: (value) => _bounded(value, 120, 'Titulok'),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _bio,
                            minLines: 4,
                            maxLines: 8,
                            maxLength: 2000,
                            decoration: const InputDecoration(labelText: 'O mne'),
                            validator: (value) => _bounded(value, 2000, 'O mne'),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _specialties,
                            maxLength: 300,
                            decoration: const InputDecoration(
                              labelText: 'Zameranie',
                              hintText: 'Silový tréning, mobilita, kondícia',
                              helperText: 'Zadajte oblasti oddelené čiarkami.',
                            ),
                            validator: (value) => _bounded(value, 300, 'Zameranie'),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _years,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Roky praxe (nepovinné)',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) return null;
                              final years = int.tryParse(value.trim());
                              return years == null || years < 0 || years > 80
                                  ? 'Zadajte celé číslo od 0 do 80.'
                                  : null;
                            },
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _saving ? null : _save,
                              icon: _saving
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.save_rounded),
                              label: const Text('Uložiť profil'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
  );
}

class PublicTrainerProfileScreen extends StatefulWidget {
  const PublicTrainerProfileScreen({super.key, required this.trainerId});
  final String trainerId;

  @override
  State<PublicTrainerProfileScreen> createState() =>
      _PublicTrainerProfileScreenState();
}

class _PublicTrainerProfileScreenState extends State<PublicTrainerProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await Supabase.instance.client.rpc(
        'get_trainer_public_profile',
        params: {'target_trainer_id': widget.trainerId},
      );
      final rows = response is List ? response : const [];
      if (rows.isEmpty) throw StateError('Profile not found');
      if (mounted) setState(() => _profile = Map<String, dynamic>.from(rows.first as Map));
    } catch (_) {
      if (mounted) setState(() => _error = 'Profil trénera sa nepodarilo načítať.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Profil trénera')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(child: Text(_error!))
        : SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: _content(_profile!),
              ),
            ),
          ),
  );

  Widget _content(Map<String, dynamic> profile) {
    final name = '${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}'.trim();
    final specialties = (profile['specialties'] as List? ?? []).cast<Object?>();
    final testimonials = (profile['testimonials'] as List? ?? [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 30,
                  child: Text(name.isEmpty ? 'T' : name.characters.first),
                ),
                const SizedBox(height: 14),
                Text(name.isEmpty ? 'Tréner' : name,
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 6),
                Text(profile['headline'] as String? ?? '',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Text(profile['bio'] as String? ?? ''),
                if (specialties.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('ZAMERANIE', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: specialties
                        .map((item) => Chip(label: Text(item.toString())))
                        .toList(),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _Stat(label: 'Klienti', value: '${profile['active_clients'] ?? 0}'),
                    _Stat(label: 'Dokončené tréningy', value: '${profile['completed_sessions'] ?? 0}'),
                    if (profile['years_experience'] != null)
                      _Stat(label: 'Roky praxe', value: '${profile['years_experience']}'),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text('HODNOTENIA KLIENTOV (${testimonials.length})',
            style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: .5)),
        const SizedBox(height: 8),
        if (testimonials.isEmpty)
          const Card(child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('Tréner zatiaľ nemá zverejnené hodnotenia.'),
          )),
        ...testimonials.map((testimonial) => Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const CircleAvatar(child: Icon(Icons.person_outline_rounded)),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('Klient', style: TextStyle(fontWeight: FontWeight.bold))),
                  Text('★ ${testimonial['rating']}/5',
                      style: const TextStyle(color: Color(0xFFB8F36B), fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 12),
                Text(testimonial['body'] as String? ?? ''),
              ],
            ),
          ),
        )),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}
