import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  static const _fields = <String, String>{
    'weight_kg': 'Hmotnosť (kg)',
    'waist_cm': 'Pás (cm)',
    'hips_cm': 'Boky (cm)',
    'thigh_cm': 'Stehno (cm)',
    'chest_cm': 'Hrudník (cm)',
    'biceps_cm': 'Biceps (cm)',
    'shoulders_cm': 'Ramená (cm)',
  };

  final _measurements = {
    for (final key in _fields.keys) key: TextEditingController(),
  };
  final _notes = TextEditingController();
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  List<Map<String, dynamic>> _history = [];
  String _chartField = 'weight_kg';
  List<Map<String, dynamic>> _habits = [];
  final Map<String, bool> _habitCheckins = {};
  final Map<String, int> _habitHistory = {};
  int? _motivation, _energy, _sleepQuality;
  bool _loading = true, _saving = false;

  SupabaseClient get _db => Supabase.instance.client;
  String get _userId => _db.auth.currentUser!.id;
  String get _dateKey => _dateString(_date);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in _measurements.values) {
      controller.dispose();
    }
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final measurement = await _db
          .from('client_body_measurements')
          .select(
            'weight_kg,waist_cm,hips_cm,thigh_cm,chest_cm,biceps_cm,shoulders_cm',
          )
          .eq('user_id', _userId)
          .eq('measured_on', _dateKey)
          .maybeSingle();
      final checkin = await _db
          .from('client_daily_checkins')
          .select(
            'nutrition_goal,nutrition_completed,training_goal,training_completed,motivation,energy,sleep_quality,notes',
          )
          .eq('user_id', _userId)
          .eq('checkin_date', _dateKey)
          .maybeSingle();
      final habitRows = await _db
          .from('client_habits')
          .select(
            'id,category,title,repeat_mode,scheduled_for,created_at,ended_on,is_active',
          )
          .eq('user_id', _userId);
      final habitCheckinRows = await _db
          .from('client_habit_checkins')
          .select('habit_id,completed')
          .eq('user_id', _userId)
          .eq('checkin_date', _dateKey);
      final today = DateUtils.dateOnly(DateTime.now());
      final historyStart = today.subtract(const Duration(days: 29));
      final habitHistoryRows = await _db
          .from('client_habit_checkins')
          .select('habit_id,completed')
          .eq('user_id', _userId)
          .eq('completed', true)
          .gte('checkin_date', _dateString(historyStart))
          .lte('checkin_date', _dateString(today));
      final history = await _db
          .from('client_body_measurements')
          .select(
            'measured_on,weight_kg,waist_cm,hips_cm,thigh_cm,chest_cm,biceps_cm,shoulders_cm',
          )
          .eq('user_id', _userId)
          .order('measured_on', ascending: false)
          .limit(60);
      if (!mounted) return;
      for (final entry in _measurements.entries) {
        final value = measurement?[entry.key];
        entry.value.text = value == null
            ? ''
            : _number((value as num).toDouble());
      }
      _notes.text = checkin?['notes'] as String? ?? '';
      final date = DateTime.parse(_dateKey);
      _habits = habitRows.map((row) => Map<String, dynamic>.from(row)).where((
        habit,
      ) {
        final mode = habit['repeat_mode'] as String;
        if (mode == 'daily') {
          return habit['is_active'] == true &&
              habit['scheduled_for'] == _dateKey;
        }
        final starts = DateTime.parse(habit['created_at'] as String);
        final startDate = DateUtils.dateOnly(starts.toLocal());
        final endedOn = habit['ended_on'] as String?;
        return !startDate.isAfter(date) &&
            (endedOn == null || !DateTime.parse(endedOn).isBefore(date));
      }).toList();
      _habitCheckins
        ..clear()
        ..addEntries(
          habitCheckinRows.map(
            (row) =>
                MapEntry(row['habit_id'] as String, row['completed'] as bool),
          ),
        );
      _habitHistory.clear();
      for (final row in habitHistoryRows) {
        final id = row['habit_id'] as String;
        _habitHistory[id] = (_habitHistory[id] ?? 0) + 1;
      }
      _motivation = checkin?['motivation'] as int?;
      _energy = checkin?['energy'] as int?;
      _sleepQuality = checkin?['sleep_quality'] as int?;
      _history = history
          .map((row) => Map<String, dynamic>.from(row))
          .toList()
          .reversed
          .toList();
    } catch (_) {
      if (mounted) _message('Údaje pokroku sa nepodarilo načítať.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateUtils.dateOnly(DateTime.now()),
      locale: const Locale('sk'),
      helpText: 'Vyberte deň',
      cancelText: 'Zrušiť',
      confirmText: 'Vybrať',
    );
    if (selected == null || !mounted) return;
    setState(() => _date = DateUtils.dateOnly(selected));
    await _load();
  }

  Future<void> _stepDate(int days) async {
    final next = DateUtils.dateOnly(_date.add(Duration(days: days)));
    if (next.isAfter(DateUtils.dateOnly(DateTime.now()))) return;
    setState(() => _date = next);
    await _load();
  }

  Future<void> _saveMeasurements() async {
    final values = <String, double>{};
    for (final entry in _measurements.entries) {
      final raw = entry.value.text.trim().replaceAll(',', '.');
      if (raw.isEmpty) continue;
      final value = double.tryParse(raw);
      if (value == null || !value.isFinite || value <= 0) {
        _message('Skontrolujte hodnotu: ${_fields[entry.key]}.');
        return;
      }
      values[entry.key] = value;
    }
    if (values.isEmpty) {
      _message('Zadajte aspoň jedno telesné meranie.');
      return;
    }
    setState(() => _saving = true);
    try {
      await _db.from('client_body_measurements').upsert({
        'user_id': _userId,
        'measured_on': _dateKey,
        ...values,
      }, onConflict: 'user_id,measured_on');
      await _load();
      if (mounted) _message('Merania boli uložené.');
    } catch (_) {
      if (mounted) _message('Merania sa nepodarilo uložiť. Skúste to znova.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveCheckin() async {
    setState(() => _saving = true);
    try {
      await _db.from('client_daily_checkins').upsert({
        'user_id': _userId,
        'checkin_date': _dateKey,
        'motivation': _motivation,
        'energy': _energy,
        'sleep_quality': _sleepQuality,
        'notes': _notes.text.trim(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id,checkin_date');
      if (mounted) _message('Denný záznam bol uložený.');
    } catch (_) {
      if (mounted) {
        _message('Denný záznam sa nepodarilo uložiť. Skúste to znova.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveHabitCheckin(String habitId, bool completed) async {
    if (_dateKey != _dateString(DateUtils.dateOnly(DateTime.now()))) return;
    setState(() => _habitCheckins[habitId] = completed);
    try {
      await _db.from('client_habit_checkins').upsert({
        'habit_id': habitId,
        'user_id': _userId,
        'checkin_date': _dateKey,
        'completed': completed,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'habit_id,checkin_date');
    } catch (_) {
      if (mounted) {
        setState(() => _habitCheckins[habitId] = !completed);
        _message('Návyk sa nepodarilo aktualizovať. Skúste to znova.');
      }
    }
  }

  Future<void> _addHabit() async {
    final title = TextEditingController();
    var category = 'nutrition';
    var repeatMode = 'fixed';
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Pridať cieľ alebo návyk'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  autofocus: true,
                  maxLength: 120,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Čo chcete dosiahnuť?',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Oblasť'),
                  items: const [
                    DropdownMenuItem(
                      value: 'nutrition',
                      child: Text('Stravovanie'),
                    ),
                    DropdownMenuItem(value: 'training', child: Text('Tréning')),
                    DropdownMenuItem(
                      value: 'custom',
                      child: Text('Vlastný návyk'),
                    ),
                  ],
                  onChanged: (value) => setDialogState(() => category = value!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: repeatMode,
                  decoration: const InputDecoration(labelText: 'Ako často?'),
                  items: const [
                    DropdownMenuItem(
                      value: 'fixed',
                      child: Text('Pevný cieľ – každý deň'),
                    ),
                    DropdownMenuItem(
                      value: 'daily',
                      child: Text('Nová úloha pre tento deň'),
                    ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => repeatMode = value!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Zrušiť'),
            ),
            FilledButton(
              onPressed: () {
                if (title.text.trim().isEmpty) return;
                Navigator.pop(dialogContext, {
                  'title': title.text.trim(),
                  'category': category,
                  'repeat_mode': repeatMode,
                });
              },
              child: const Text('Pridať'),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    if (result == null) return;
    try {
      await _db.from('client_habits').insert({
        'user_id': _userId,
        'title': result['title'],
        'category': result['category'],
        'repeat_mode': result['repeat_mode'],
        if (result['repeat_mode'] == 'daily') 'scheduled_for': _dateKey,
      });
      await _load();
      if (mounted) _message('Cieľ bol pridaný.');
    } catch (_) {
      if (mounted) _message('Cieľ sa nepodarilo pridať. Skúste to znova.');
    }
  }

  Future<void> _removeHabit(Map<String, dynamic> habit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Odstrániť cieľ?'),
        content: Text('„${habit['title']}“ sa odstráni aj z prehľadu návykov.'),
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
    if (confirmed != true) return;
    try {
      if (habit['repeat_mode'] == 'fixed') {
        await _db
            .from('client_habits')
            .update({
              'is_active': false,
              'ended_on': _dateString(
                DateUtils.dateOnly(
                  DateTime.now(),
                ).subtract(const Duration(days: 1)),
              ),
            })
            .eq('id', habit['id']);
      } else {
        await _db
            .from('client_habits')
            .update({'is_active': false})
            .eq('id', habit['id']);
      }
      await _load();
    } catch (_) {
      if (mounted) _message('Cieľ sa nepodarilo odstrániť.');
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  int get _configuredGoals => _habits.length;

  int get _completedGoals =>
      _habits.where((habit) => _habitCheckins[habit['id']] == true).length;

  String _dateString(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _number(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);

  String _formattedDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF38D1BF)),
                const SizedBox(width: 10),
                Text(title, style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }

  Widget _rating(String label, int? value, ValueChanged<int?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: List.generate(10, (index) {
              final score = index + 1;
              return ChoiceChip(
                label: Text('$score'),
                selected: value == score,
                onSelected: (_) =>
                    setState(() => onChanged(value == score ? null : score)),
              );
            }),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final percentage = _configuredGoals == 0
        ? 0
        : (_completedGoals * 100 / _configuredGoals).round();
    final chartRows = _history.where((row) => row[_chartField] is num).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Môj pokrok')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  _sectionCard(
                    title: 'Vybraný deň',
                    icon: Icons.calendar_month_rounded,
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Predchádzajúci deň',
                          onPressed: () => _stepDate(-1),
                          icon: const Icon(Icons.chevron_left_rounded),
                        ),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickDate,
                            icon: const Icon(Icons.edit_calendar_rounded),
                            label: Text(_formattedDate(_date)),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Nasledujúci deň',
                          onPressed: _date.isBefore(today)
                              ? () => _stepDate(1)
                              : null,
                          icon: const Icon(Icons.chevron_right_rounded),
                        ),
                      ],
                    ),
                  ),
                  _sectionCard(
                    title: 'Telesné merania',
                    icon: Icons.monitor_weight_outlined,
                    child: Column(
                      children: [
                        for (final entry in _fields.entries) ...[
                          TextField(
                            controller: _measurements[entry.key],
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: entry.value,
                              suffixIcon: IconButton(
                                tooltip:
                                    'Zobraziť ${entry.value.toLowerCase()} v grafe',
                                onPressed: () =>
                                    setState(() => _chartField = entry.key),
                                icon: Icon(
                                  Icons.show_chart_rounded,
                                  color: _chartField == entry.key
                                      ? const Color(0xFF38D1BF)
                                      : null,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _saving ? null : _saveMeasurements,
                            icon: _saving
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save_rounded),
                            label: const Text('Uložiť merania'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _sectionCard(
                    title: 'História meraní',
                    icon: Icons.insights_rounded,
                    child: chartRows.isEmpty
                        ? const Text(
                            'Pre tento údaj zatiaľ nemáte uložené merania.',
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _fields[_chartField]!,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 190,
                                width: double.infinity,
                                child: CustomPaint(
                                  painter: _ProgressChartPainter(
                                    rows: chartRows,
                                    field: _chartField,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    gridColor: Theme.of(context).dividerColor,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${_formattedDate(DateTime.parse(chartRows.first['measured_on'] as String))} – ${_formattedDate(DateTime.parse(chartRows.last['measured_on'] as String))}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                  ),
                  _sectionCard(
                    title: 'Denné návyky',
                    icon: Icons.task_alt_rounded,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Denný cieľ splnený',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            Text(
                              '$percentage%',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: _configuredGoals == 0
                              ? 0
                              : _completedGoals / _configuredGoals,
                        ),
                        const SizedBox(height: 12),
                        if (_habits.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'Na tento deň zatiaľ nemáte pridané ciele.',
                            ),
                          )
                        else
                          for (final habit in _habits)
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              value:
                                  _habitCheckins[habit['id'] as String] ??
                                  false,
                              title: Text(habit['title'] as String),
                              subtitle: Text(
                                '${_categoryLabel(habit['category'] as String)} · ${habit['repeat_mode'] == 'fixed' ? 'Pevný cieľ' : 'Úloha na tento deň'} · ${_habitHistory[habit['id']] ?? 0}/30 dní splnených',
                              ),
                              secondary: IconButton(
                                tooltip: 'Ukončiť cieľ',
                                onPressed: () => _removeHabit(habit),
                                icon: const Icon(Icons.archive_outlined),
                              ),
                              onChanged: _dateKey == _dateString(today)
                                  ? (value) => _saveHabitCheckin(
                                      habit['id'] as String,
                                      value ?? false,
                                    )
                                  : null,
                            ),
                        OutlinedButton.icon(
                          onPressed: _addHabit,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Pridať cieľ alebo návyk'),
                        ),
                        const Divider(height: 24),
                        _rating(
                          'Motivácia',
                          _motivation,
                          (value) => _motivation = value,
                        ),
                        _rating('Energia', _energy, (value) => _energy = value),
                        _rating(
                          'Kvalita spánku',
                          _sleepQuality,
                          (value) => _sleepQuality = value,
                        ),
                        TextField(
                          controller: _notes,
                          minLines: 2,
                          maxLines: 4,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            labelText: 'Poznámky k dňu',
                            alignLabelWithHint: true,
                            prefixIcon: Icon(Icons.notes_rounded),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _saving ? null : _saveCheckin,
                            icon: const Icon(
                              Icons.check_circle_outline_rounded,
                            ),
                            label: const Text('Uložiť denný záznam'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  String _categoryLabel(String category) => switch (category) {
    'nutrition' => 'Stravovanie',
    'training' => 'Tréning',
    _ => 'Vlastný návyk',
  };
}

class _ProgressChartPainter extends CustomPainter {
  const _ProgressChartPainter({
    required this.rows,
    required this.field,
    required this.color,
    required this.gridColor,
  });

  final List<Map<String, dynamic>> rows;
  final String field;
  final Color color;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    const padding = EdgeInsets.fromLTRB(32, 12, 12, 18);
    final chart = Rect.fromLTRB(
      padding.left,
      padding.top,
      size.width - padding.right,
      size.height - padding.bottom,
    );
    final values = rows.map((row) => (row[field] as num).toDouble()).toList();
    var minimum = values.reduce(math.min);
    var maximum = values.reduce(math.max);
    if (minimum == maximum) {
      minimum -= 1;
      maximum += 1;
    } else {
      final breathingRoom = (maximum - minimum) * .12;
      minimum -= breathingRoom;
      maximum += breathingRoom;
    }
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: .45)
      ..strokeWidth = 1;
    for (var line = 0; line < 4; line++) {
      final y = chart.top + chart.height * line / 3;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
    }
    final points = <Offset>[];
    for (var index = 0; index < values.length; index++) {
      final x = values.length == 1
          ? chart.center.dx
          : chart.left + chart.width * index / (values.length - 1);
      final y =
          chart.bottom -
          (values[index] - minimum) / (maximum - minimum) * chart.height;
      points.add(Offset(x, y));
    }
    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      line.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    final pointPaint = Paint()..color = color;
    for (var index = 0; index < points.length; index++) {
      canvas.drawCircle(points[index], 4, pointPaint);
      if (index == 0 || index == points.length - 1) {
        final text = TextPainter(
          text: TextSpan(
            text: _number(values[index]),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final x = index == 0 ? points[index].dx : points[index].dx - text.width;
        text.paint(canvas, Offset(x, points[index].dy - text.height - 6));
      }
    }
  }

  String _number(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);

  @override
  bool shouldRepaint(covariant _ProgressChartPainter oldDelegate) =>
      oldDelegate.rows != rows ||
      oldDelegate.field != field ||
      oldDelegate.color != color ||
      oldDelegate.gridColor != gridColor;
}
