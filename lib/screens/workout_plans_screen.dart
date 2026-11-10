import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WorkoutPlansScreen extends StatefulWidget {
  const WorkoutPlansScreen({
    this.connection,
    required this.currentRole,
    super.key,
  });

  final Map<String, dynamic>? connection;
  final String currentRole;

  @override
  State<WorkoutPlansScreen> createState() => _WorkoutPlansScreenState();
}

class _WorkoutPlansScreenState extends State<WorkoutPlansScreen> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _plans = [];
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  bool get _isTrainer => widget.currentRole == 'trainer';
  bool get _isPersonal => !_isTrainer && widget.connection == null;
  bool get _canManagePlans => _isTrainer || _isPersonal;
  String? get _trainerId => widget.connection?['trainer_id'] as String?;
  String get _clientId =>
      widget.connection?['client_id'] as String? ??
      _client.auth.currentUser!.id;
  String get _counterpartName {
    final name =
        '${widget.connection?['counterpart_first_name'] ?? ''} '
                '${widget.connection?['counterpart_last_name'] ?? ''}'
            .trim();
    return name.isEmpty
        ? (widget.connection?['counterpart_email'] as String? ??
              (_isPersonal ? 'Mňa' : 'Spolupracovník'))
        : name;
  }

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
      final planQuery = _client
          .from('workout_plans')
          .select(
            'id, trainer_id, client_id, title, description, sessions, created_at',
          )
          .eq('client_id', _clientId);
      final logQuery = _client
          .from('workout_session_logs')
          .select(
            'id, plan_id, trainer_id, client_id, session_index, completed_exercises, notes, completed_at',
          )
          .eq('client_id', _clientId);
      if (_isPersonal) {
        planQuery.isFilter('trainer_id', null);
        logQuery.isFilter('trainer_id', null);
      } else {
        planQuery.eq('trainer_id', _trainerId!);
        logQuery.eq('trainer_id', _trainerId!);
      }
      final values = await Future.wait<Object?>([
        planQuery.order('created_at', ascending: false),
        logQuery.order('completed_at', ascending: false),
      ]);
      if (!mounted) return;
      setState(() {
        _plans = _maps(values[0]);
        _logs = _maps(values[1]);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Tréningové plány sa nepodarilo načítať.';
        _loading = false;
      });
    }
  }

  Future<void> _editPlan([Map<String, dynamic>? plan]) async {
    final draft = await showDialog<_PlanDraft>(
      context: context,
      builder: (_) => _PlanEditorDialog(plan: plan),
    );
    if (draft == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final values = {
        'title': draft.title,
        'description': draft.description,
        'sessions': draft.sessions,
      };
      if (plan == null) {
        await _client.from('workout_plans').insert({
          ...values,
          'trainer_id': _trainerId,
          'client_id': _clientId,
        });
      } else {
        await _client.from('workout_plans').update(values).eq('id', plan['id']);
      }
      if (mounted) {
        _message(
          plan == null ? 'Plán bol vytvorený.' : 'Plán bol aktualizovaný.',
        );
      }
      await _load();
    } catch (_) {
      if (mounted) _message('Plán sa nepodarilo uložiť. Skúste to znova.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logSession(Map<String, dynamic> plan, int sessionIndex) async {
    final session = _sessions(plan['sessions'])[sessionIndex];
    final result = await showDialog<_SessionResult>(
      context: context,
      builder: (_) => _SessionLogDialog(
        title: session['name'] as String? ?? 'Tréning ${sessionIndex + 1}',
        exercises: _exercises(
          session['exercises'],
        ).map(_exerciseLabel).toList(),
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await _client.from('workout_session_logs').insert({
        'plan_id': plan['id'],
        'trainer_id': _trainerId,
        'client_id': _clientId,
        'session_index': sessionIndex,
        'completed_exercises': result.completedExercises,
        'notes': result.notes,
      });
      if (mounted) _message('Tréning bol zaznamenaný.');
      await _load();
    } catch (_) {
      if (mounted) {
        _message('Tréning sa nepodarilo zaznamenať. Skúste to znova.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<Map<String, dynamic>> _sessions(Object? value) => value is List
      ? value.whereType<Map>().map(Map<String, dynamic>.from).toList()
      : [];

  List<String> _strings(Object? value) =>
      value is List ? value.whereType<String>().toList() : [];

  List<Map<String, dynamic>> _exercises(Object? value) => value is List
      ? value
            .map((item) {
              if (item is String) return {'name': item};
              if (item is Map) return Map<String, dynamic>.from(item);
              return null;
            })
            .whereType<Map<String, dynamic>>()
            .where((exercise) => _exerciseName(exercise).isNotEmpty)
            .toList()
      : [];

  String _exerciseName(Map<String, dynamic> exercise) =>
      (exercise['name'] as String? ?? exercise['exercise'] as String? ?? '')
          .trim();

  int? _exerciseNumber(Map<String, dynamic> exercise, String key) {
    final value = exercise[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  String _exerciseLabel(Map<String, dynamic> exercise) {
    final details = <String>[];
    final sets = _exerciseNumber(exercise, 'sets');
    final reps = _exerciseNumber(exercise, 'reps');
    final rest = _exerciseNumber(exercise, 'rest_seconds');
    if (sets != null && reps != null) details.add('$sets × $reps');
    if (rest != null) details.add('pauza ${rest}s');
    final name = _exerciseName(exercise);
    return details.isEmpty ? name : '$name (${details.join(', ')})';
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _exportPlan(Map<String, dynamic> plan) async {
    final document = pw.Document();
    final sessions = _sessions(plan['sessions']);
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (_) => [
          pw.Text(
            _plainText(plan['title'] as String? ?? 'Tréningový plán'),
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text(_plainText('Klient: $_counterpartName')),
          if ((plan['description'] as String? ?? '').trim().isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Text(_plainText(plan['description'] as String)),
          ],
          pw.SizedBox(height: 20),
          ...sessions.asMap().entries.map(
            (entry) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  _plainText(
                    entry.value['name'] as String? ??
                        'Tréning ${entry.key + 1}',
                  ),
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                ..._exercises(entry.value['exercises']).map(
                  (exercise) =>
                      pw.Bullet(text: _plainText(_exerciseLabel(exercise))),
                ),
                pw.SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
    await Printing.layoutPdf(
      onLayout: (_) async => document.save(),
      name: '${_fileName(plan['title'] as String? ?? 'trenningovy-plan')}.pdf',
    );
  }

  String _fileName(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  String _plainText(String value) {
    const replacements = {
      'á': 'a',
      'ä': 'a',
      'č': 'c',
      'ď': 'd',
      'é': 'e',
      'í': 'i',
      'ĺ': 'l',
      'ľ': 'l',
      'ň': 'n',
      'ó': 'o',
      'ô': 'o',
      'ŕ': 'r',
      'š': 's',
      'ť': 't',
      'ú': 'u',
      'ý': 'y',
      'ž': 'z',
      'Á': 'A',
      'Ä': 'A',
      'Č': 'C',
      'Ď': 'D',
      'É': 'E',
      'Í': 'I',
      'Ĺ': 'L',
      'Ľ': 'L',
      'Ň': 'N',
      'Ó': 'O',
      'Ô': 'O',
      'Ŕ': 'R',
      'Š': 'S',
      'Ť': 'T',
      'Ú': 'U',
      'Ý': 'Y',
      'Ž': 'Z',
    };
    return value.split('').map((c) => replacements[c] ?? c).join();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isTrainer
              ? 'Plány pre $_counterpartName'
              : _isPersonal
              ? 'Môj vlastný plán'
              : 'Moje tréningy',
        ),
        actions: [
          IconButton(
            tooltip: 'Obnoviť',
            onPressed: _loading || _busy ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: _canManagePlans
          ? FloatingActionButton.extended(
              onPressed: _busy ? null : () => _editPlan(),
              icon: const Icon(Icons.add),
              label: const Text('Nový plán'),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorState(message: _error!, onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: EdgeInsets.symmetric(
                  horizontal: width >= 900 ? (width - 820) / 2 : 16,
                  vertical: 16,
                ),
                children: [
                  if (_plans.isEmpty)
                    _EmptyCard(
                      icon: Icons.fitness_center,
                      text: _isTrainer
                          ? 'Zatiaľ ste pre tohto klienta nevytvorili tréningový plán.'
                          : _isPersonal
                          ? 'Zatiaľ nemáte vytvorený vlastný tréningový plán.'
                          : 'Tréner pre vás zatiaľ nevytvoril tréningový plán.',
                    ),
                  ..._plans.map(_planCard),
                  const SizedBox(height: 20),
                  Text(
                    'Záznamy tréningov',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  if (_logs.isEmpty)
                    const _EmptyCard(
                      icon: Icons.event_note,
                      text: 'Zatiaľ tu nie sú zaznamenané tréningy.',
                    )
                  else
                    ..._logs.map(_logCard),
                  if (_canManagePlans) const SizedBox(height: 88),
                ],
              ),
            ),
    );
  }

  Widget _planCard(Map<String, dynamic> plan) {
    final sessions = _sessions(plan['sessions']);
    final description = (plan['description'] as String? ?? '').trim();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan['title'] as String? ?? 'Tréningový plán',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(description),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Exportovať alebo tlačiť PDF',
                  onPressed: _busy ? null : () => _exportPlan(plan),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                ),
                if (_canManagePlans)
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') _editPlan(plan);
                      if (value == 'delete') _deletePlan(plan);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Upraviť')),
                      PopupMenuItem(value: 'delete', child: Text('Odstrániť')),
                    ],
                  ),
              ],
            ),
            const Divider(height: 24),
            if (sessions.isEmpty)
              const Text('Plán zatiaľ neobsahuje tréningové jednotky.')
            else
              ...sessions.asMap().entries.map((entry) {
                final index = entry.key;
                final session = entry.value;
                final exercises = _exercises(session['exercises']);
                final logged = _logs.any(
                  (log) =>
                      log['plan_id'] == plan['id'] &&
                      log['session_index'] == index,
                );
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(child: Text('${index + 1}')),
                  title: Text(
                    session['name'] as String? ?? 'Tréning ${index + 1}',
                  ),
                  subtitle: Text(
                    exercises.isEmpty
                        ? 'Bez uvedených cvikov'
                        : exercises.map(_exerciseLabel).join(' • '),
                  ),
                  trailing: _isTrainer
                      ? (logged
                            ? const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              )
                            : null)
                      : TextButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _logSession(plan, index),
                          icon: const Icon(Icons.check),
                          label: Text(
                            logged ? 'Zaznamenať znova' : 'Zaznamenať',
                          ),
                        ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _logCard(Map<String, dynamic> log) {
    Map<String, dynamic>? plan;
    for (final item in _plans) {
      if (item['id'] == log['plan_id']) {
        plan = item;
        break;
      }
    }
    final index = log['session_index'] is int
        ? log['session_index'] as int
        : -1;
    final sessions = plan == null
        ? <Map<String, dynamic>>[]
        : _sessions(plan['sessions']);
    final title = index >= 0 && index < sessions.length
        ? (sessions[index]['name'] as String? ?? 'Tréning ${index + 1}')
        : 'Dokončený tréning';
    final date = DateTime.tryParse(
      log['completed_at'] as String? ?? '',
    )?.toLocal();
    final exercises = _strings(log['completed_exercises']);
    final notes = (log['notes'] as String? ?? '').trim();
    return Card(
      child: ListTile(
        leading: const Icon(Icons.check_circle_outline),
        title: Text(title),
        subtitle: Text(
          [
            if (date != null)
              MaterialLocalizations.of(context).formatMediumDate(date),
            if (exercises.isNotEmpty) exercises.join(' • '),
            if (notes.isNotEmpty) notes,
          ].join('\n'),
        ),
        isThreeLine: exercises.isNotEmpty || notes.isNotEmpty,
      ),
    );
  }

  Future<void> _deletePlan(Map<String, dynamic> plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Odstrániť plán?'),
        content: Text('Plán „${plan['title']}“ bude odstránený.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Zrušiť'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Odstrániť'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _client.from('workout_plans').delete().eq('id', plan['id']);
      if (mounted) _message('Plán bol odstránený.');
      await _load();
    } catch (_) {
      if (mounted) _message('Plán sa nepodarilo odstrániť.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 8),
          Text(text, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
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
            icon: const Icon(Icons.refresh),
            label: const Text('Skúsiť znova'),
          ),
        ],
      ),
    ),
  );
}

class _PlanDraft {
  const _PlanDraft({
    required this.title,
    required this.description,
    required this.sessions,
  });
  final String title;
  final String description;
  final List<Map<String, dynamic>> sessions;
}

class _PlanEditorDialog extends StatefulWidget {
  const _PlanEditorDialog({this.plan});
  final Map<String, dynamic>? plan;

  @override
  State<_PlanEditorDialog> createState() => _PlanEditorDialogState();
}

class _PlanEditorDialogState extends State<_PlanEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final List<_SessionDraft> _sessions;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(
      text: widget.plan?['title'] as String? ?? '',
    );
    _description = TextEditingController(
      text: widget.plan?['description'] as String? ?? '',
    );
    final raw = widget.plan?['sessions'];
    _sessions = raw is List
        ? raw
              .whereType<Map>()
              .map(
                (session) => _SessionDraft(
                  name: session['name'] as String? ?? '',
                  exercises: session['exercises'] is List
                      ? (session['exercises'] as List)
                            .map((exercise) {
                              if (exercise is String) {
                                return _ExerciseDraft(name: exercise);
                              }
                              if (exercise is Map) {
                                return _ExerciseDraft(
                                  name:
                                      exercise['name'] as String? ??
                                      exercise['exercise'] as String? ??
                                      '',
                                  sets: exercise['sets']?.toString() ?? '',
                                  reps: exercise['reps']?.toString() ?? '',
                                  restSeconds:
                                      exercise['rest_seconds']?.toString() ??
                                      '',
                                );
                              }
                              return null;
                            })
                            .whereType<_ExerciseDraft>()
                            .toList()
                      : null,
                ),
              )
              .toList()
        : [];
    if (_sessions.isEmpty) _sessions.add(_SessionDraft());
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    for (final session in _sessions) {
      session.dispose();
    }
    super.dispose();
  }

  void _addSession() => setState(() => _sessions.add(_SessionDraft()));

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.plan == null ? 'Nový tréningový plán' : 'Upraviť plán'),
    content: SizedBox(
      width: 520,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _title,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Názov plánu'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Zadajte názov.'
                    : null,
              ),
              TextFormField(
                controller: _description,
                decoration: const InputDecoration(
                  labelText: 'Popis (nepovinné)',
                ),
                minLines: 1,
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < _sessions.length; i++) _sessionEditor(i),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addSession,
                  icon: const Icon(Icons.add),
                  label: const Text('Pridať tréning'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Zrušiť'),
      ),
      FilledButton(
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          final sessions = _sessions
              .map(
                (session) => {
                  'name': session.name.text.trim().isEmpty
                      ? 'Tréning'
                      : session.name.text.trim(),
                  'exercises': session.exercises
                      .where((exercise) => exercise.name.text.trim().isNotEmpty)
                      .map((exercise) => exercise.toJson())
                      .toList(),
                },
              )
              .toList();
          Navigator.pop(
            context,
            _PlanDraft(
              title: _title.text.trim(),
              description: _description.text.trim(),
              sessions: sessions,
            ),
          );
        },
        child: const Text('Uložiť'),
      ),
    ],
  );

  Widget _sessionEditor(int index) {
    final session = _sessions[index];
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Tréning ${index + 1}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (_sessions.length > 1)
                  IconButton(
                    tooltip: 'Odstrániť tréning',
                    onPressed: () => setState(() {
                      _sessions.removeAt(index).dispose();
                    }),
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
            TextField(
              controller: session.name,
              decoration: const InputDecoration(labelText: 'Názov tréningu'),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Spoločné nastavenia',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Row(
              children: [
                _numberField(session.sharedSets, 'Série'),
                const SizedBox(width: 8),
                _numberField(session.sharedReps, 'Opakovania'),
                const SizedBox(width: 8),
                _numberField(session.sharedRest, 'Pauza (s)'),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(session.applySharedSettings),
                icon: const Icon(Icons.done_all),
                label: const Text('Použiť na všetky cviky'),
              ),
            ),
            for (var i = 0; i < session.exercises.length; i++)
              _exerciseEditor(session, i),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => session.addExercise()),
                icon: const Icon(Icons.add),
                label: const Text('Pridať cvik'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _numberField(TextEditingController controller, String label) =>
      Expanded(
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: label),
        ),
      );

  Widget _exerciseEditor(_SessionDraft session, int index) {
    final exercise = session.exercises[index];
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: exercise.name,
                  decoration: InputDecoration(labelText: 'Cvik ${index + 1}'),
                ),
              ),
              IconButton(
                tooltip: 'Odstrániť cvik',
                onPressed: () => setState(() => session.removeExercise(index)),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          Row(
            children: [
              _numberField(exercise.sets, 'Série'),
              const SizedBox(width: 8),
              _numberField(exercise.reps, 'Opakovania'),
              const SizedBox(width: 8),
              _numberField(exercise.restSeconds, 'Pauza (s)'),
            ],
          ),
        ],
      ),
    );
  }
}

class _SessionDraft {
  _SessionDraft({String name = '', List<_ExerciseDraft>? exercises})
    : name = TextEditingController(text: name),
      exercises = exercises ?? [],
      sharedSets = TextEditingController(text: '3'),
      sharedReps = TextEditingController(text: '10'),
      sharedRest = TextEditingController(text: '60');

  final TextEditingController name;
  final List<_ExerciseDraft> exercises;
  final TextEditingController sharedSets;
  final TextEditingController sharedReps;
  final TextEditingController sharedRest;

  void addExercise() => exercises.add(
    _ExerciseDraft(
      sets: sharedSets.text,
      reps: sharedReps.text,
      restSeconds: sharedRest.text,
    ),
  );

  void removeExercise(int index) => exercises.removeAt(index).dispose();

  void applySharedSettings() {
    for (final exercise in exercises) {
      exercise.sets.text = sharedSets.text;
      exercise.reps.text = sharedReps.text;
      exercise.restSeconds.text = sharedRest.text;
    }
  }

  void dispose() {
    name.dispose();
    sharedSets.dispose();
    sharedReps.dispose();
    sharedRest.dispose();
    for (final exercise in exercises) {
      exercise.dispose();
    }
  }
}

class _ExerciseDraft {
  _ExerciseDraft({
    String name = '',
    String sets = '',
    String reps = '',
    String restSeconds = '',
  }) : name = TextEditingController(text: name),
       sets = TextEditingController(text: sets),
       reps = TextEditingController(text: reps),
       restSeconds = TextEditingController(text: restSeconds);

  final TextEditingController name;
  final TextEditingController sets;
  final TextEditingController reps;
  final TextEditingController restSeconds;

  Map<String, dynamic> toJson() => {
    'name': name.text.trim(),
    if (int.tryParse(sets.text.trim()) case final value?) 'sets': value,
    if (int.tryParse(reps.text.trim()) case final value?) 'reps': value,
    if (int.tryParse(restSeconds.text.trim()) case final value?)
      'rest_seconds': value,
  };

  void dispose() {
    name.dispose();
    sets.dispose();
    reps.dispose();
    restSeconds.dispose();
  }
}

class _SessionResult {
  const _SessionResult({required this.completedExercises, required this.notes});
  final List<String> completedExercises;
  final String notes;
}

class _SessionLogDialog extends StatefulWidget {
  const _SessionLogDialog({required this.title, required this.exercises});
  final String title;
  final List<String> exercises;

  @override
  State<_SessionLogDialog> createState() => _SessionLogDialogState();
}

class _SessionLogDialogState extends State<_SessionLogDialog> {
  late final List<bool> _completed;
  final _notes = TextEditingController();

  @override
  void initState() {
    super.initState();
    _completed = List<bool>.filled(widget.exercises.length, true);
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Zaznamenať: ${widget.title}'),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.exercises.isEmpty)
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Tento tréning nemá uvedené cviky.'),
              )
            else
              ...List.generate(
                widget.exercises.length,
                (index) => CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(widget.exercises[index]),
                  value: _completed[index],
                  onChanged: (value) =>
                      setState(() => _completed[index] = value ?? false),
                ),
              ),
            TextField(
              controller: _notes,
              decoration: const InputDecoration(
                labelText: 'Poznámka',
                hintText: 'Ako tréning prebehol?',
              ),
              minLines: 2,
              maxLines: 4,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Zrušiť'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(
          context,
          _SessionResult(
            completedExercises: [
              for (var i = 0; i < widget.exercises.length; i++)
                if (_completed[i]) widget.exercises[i],
            ],
            notes: _notes.text.trim(),
          ),
        ),
        child: const Text('Uložiť záznam'),
      ),
    ],
  );
}
