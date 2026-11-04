import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'food_search_screen.dart';
import 'collaboration_screen.dart';
import 'profile_screen.dart';

const mealSections = <String, String>{
  'breakfast': 'Raňajky',
  'snack': 'Desiata',
  'lunch': 'Obed',
  'afternoon_snack': 'Olovrant',
  'dinner': 'Večera',
};

class Food {
  const Food({
    required this.id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    required this.sugar,
    required this.salt,
    this.isLiquid = false,
  });

  final String id;
  final String name;
  final double? calories;
  final double? protein;
  final double? carbs;
  final double? fat;
  final double? fiber;
  final double? sugar;
  final double? salt;
  final bool isLiquid;

  factory Food.fromMap(Map<String, Object?> row) => Food(
    id: (row['food_id'] ?? row['id']).toString(),
    name: (row['name'] ?? row['food_name']) as String,
    calories: (row['calories'] as num?)?.toDouble(),
    protein: ((row['proteins'] ?? row['protein']) as num?)?.toDouble(),
    carbs: ((row['carbohydrates'] ?? row['carbs']) as num?)?.toDouble(),
    fat: ((row['fats'] ?? row['fat']) as num?)?.toDouble(),
    fiber: (row['fiber'] as num?)?.toDouble(),
    sugar: (row['sugar'] as num?)?.toDouble(),
    salt: (row['salt'] as num?)?.toDouble(),
    isLiquid: row['is_liquid'] as bool? ?? false,
  );
}

class DailyFoodEntry {
  const DailyFoodEntry({
    required this.id,
    required this.food,
    required this.quantity,
    required this.unit,
    required this.mealSection,
  });
  final String id;
  final Food food;
  final double quantity;
  final String unit;
  final String mealSection;

  double? get calories => _scaled(food.calories);
  double? get protein => _scaled(food.protein);
  double? get carbs => _scaled(food.carbs);
  double? get fat => _scaled(food.fat);
  double? get fiber => _scaled(food.fiber);
  double? get sugar => _scaled(food.sugar);
  double? get salt => _scaled(food.salt);

  double? _scaled(double? value) =>
      value == null ? null : value * quantity / 100;

  factory DailyFoodEntry.fromMap(Map<String, Object?> row) => DailyFoodEntry(
    id: row['id'] as String,
    food: Food.fromMap(row),
    quantity: (row['quantity'] as num?)?.toDouble() ?? 100,
    unit: row['unit'] as String? ?? 'g',
    mealSection: row['meal_section'] as String? ?? 'lunch',
  );
}

class FoodHomeScreen extends StatefulWidget {
  const FoodHomeScreen({super.key});

  @override
  State<FoodHomeScreen> createState() => _FoodHomeScreenState();
}

class _FoodHomeScreenState extends State<FoodHomeScreen> {
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  List<DailyFoodEntry> _entries = [];
  bool _loading = true;
  String? _error;

  String get _dateKey =>
      '${_date.year.toString().padLeft(4, '0')}-'
      '${_date.month.toString().padLeft(2, '0')}-'
      '${_date.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await Supabase.instance.client
          .from('daily_food_entries')
          .select(
            'id,food_id,name:food_name,calories,proteins,carbohydrates,fats,fiber,sugar,salt,quantity,unit,meal_section',
          )
          .eq('entry_date', _dateKey)
          .order('created_at');
      if (!mounted) return;
      setState(() {
        _entries = rows.map((row) => DailyFoodEntry.fromMap(row)).toList();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _chooseDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: today,
      locale: const Locale('sk'),
      helpText: 'Vyberte deň',
      cancelText: 'Zrušiť',
      confirmText: 'Vybrať',
    );
    if (selected == null || !mounted) return;
    setState(() => _date = DateUtils.dateOnly(selected));
    await _loadEntries();
  }

  Future<void> _changeDate(int days) async {
    setState(() => _date = DateUtils.dateOnly(_date.add(Duration(days: days))));
    await _loadEntries();
  }

  Future<void> _addFood(
    Food food,
    double quantity,
    String unit,
    String mealSection,
  ) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) throw StateError('Nie ste prihlásený.');
    await Supabase.instance.client.from('daily_food_entries').insert({
      'user_id': userId,
      'food_id': food.id,
      'food_name': food.name,
      'calories': food.calories,
      'proteins': food.protein,
      'carbohydrates': food.carbs,
      'fats': food.fat,
      'fiber': food.fiber,
      'sugar': food.sugar,
      'salt': food.salt,
      'quantity': quantity,
      'unit': unit,
      'meal_section': mealSection,
      'entry_date': _dateKey,
    });
    await _loadEntries();
  }

  Future<void> _openFoodSearch() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => FoodSearchScreen(
          onAddFood: _addFood,
          addedFoodIds: _entries.map((entry) => entry.food.id).toSet(),
        ),
      ),
    );
    if (added == true) await _loadEntries();
  }

  Future<void> _removeEntry(DailyFoodEntry entry) async {
    try {
      await Supabase.instance.client
          .from('daily_food_entries')
          .delete()
          .eq('id', entry.id);
      await _loadEntries();
    } catch (_) {
      if (mounted) _message('Jedlo sa nepodarilo odstrániť.');
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    double totalFor(double? Function(DailyFoodEntry entry) value) =>
        _entries.fold<double>(0, (sum, entry) => sum + (value(entry) ?? 0));
    final calories = totalFor((entry) => entry.calories);
    final protein = totalFor((entry) => entry.protein);
    final carbs = totalFor((entry) => entry.carbs);
    final fat = totalFor((entry) => entry.fat);
    final fiber = totalFor((entry) => entry.fiber);
    final sugar = totalFor((entry) => entry.sugar);
    final salt = totalFor((entry) => entry.salt);
    final today = DateUtils.dateOnly(DateTime.now());
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFB8F36B).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFB8F36B).withValues(alpha: 0.3),
                ),
              ),
              child: const Icon(
                Icons.eco_rounded,
                color: Color(0xFFB8F36B),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Môj denník',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 3),
                Text(
                  'DENNÝ PREHĽAD VÝŽIVY',
                  style: TextStyle(
                    color: Color(0xFF9AA59D),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Tréner a klient',
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => const CollaborationScreen()),
            ),
            icon: const Icon(Icons.fitness_center_rounded),
          ),
          IconButton(
            tooltip: 'Môj profil',
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
            icon: const Icon(Icons.account_circle_outlined),
          ),
          IconButton(
            tooltip: 'Odhlásiť sa',
            onPressed: () => Supabase.instance.client.auth.signOut(),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openFoodSearch,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Pridať jedlo'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadEntries,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            _DateCard(
              date: _date,
              onTap: _chooseDate,
              onPrevious: () => _changeDate(-1),
              onNext: _date.isBefore(today) ? () => _changeDate(1) : null,
            ),
            const SizedBox(height: 16),
            _CaloriesCard(
              calories: calories,
              protein: protein,
              carbs: carbs,
              fat: fat,
              fiber: fiber,
              sugar: sugar,
              salt: salt,
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'ZJEDENÉ JEDLÁ',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                ),
                Text('${_entries.length}'),
              ],
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _EmptyCard(
                message: 'Denník sa nepodarilo načítať.',
                action: TextButton.icon(
                  onPressed: _loadEntries,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Skúsiť znova'),
                ),
              )
            else ...[
              if (_entries.isEmpty)
                const _EmptyCard(
                  message:
                      'Pre tento deň tu ešte nič nie je. Ťuknite na „Pridať jedlo“, vyberte potravinu a jej sekciu.',
                ),
              ...mealSections.entries.expand((section) {
                final sectionEntries = _entries
                    .where((entry) => entry.mealSection == section.key)
                    .toList();
                return <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(2, 14, 2, 6),
                    child: Text(
                      section.value.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFFB8F36B),
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  if (sectionEntries.isEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(2, 0, 2, 8),
                      child: Text(
                        'Zatiaľ bez jedál',
                        style: TextStyle(
                          color: Color(0xFF7E8981),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ...sectionEntries.map(
                    (entry) => _FoodTile(
                      entry: entry,
                      trailing: IconButton(
                        tooltip: 'Odstrániť ${entry.food.name}',
                        onPressed: () => _removeEntry(entry),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ),
                  ),
                ];
              }),
            ],
          ],
        ),
      ),
    );
  }
}

class _DateCard extends StatelessWidget {
  const _DateCard({
    required this.date,
    required this.onTap,
    required this.onPrevious,
    required this.onNext,
  });
  final DateTime date;
  final VoidCallback onTap;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: const Color(0xFF141815),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFF252C27)),
    ),
    child: Row(
      children: [
        IconButton(onPressed: onPrevious, icon: const Icon(Icons.chevron_left)),
        Expanded(
          child: TextButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.calendar_month_rounded),
            label: Text(
              '${date.day}. ${_monthName(date.month)} ${date.year}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
      ],
    ),
  );
}

String _monthName(int month) => const [
  'január',
  'február',
  'marec',
  'apríl',
  'máj',
  'jún',
  'júl',
  'august',
  'september',
  'október',
  'november',
  'december',
][month - 1];

class _CaloriesCard extends StatelessWidget {
  const _CaloriesCard({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    required this.sugar,
    required this.salt,
  });
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final double sugar;
  final double salt;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF1B241B),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFF2A3529)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.local_fire_department_rounded),
            const SizedBox(width: 10),
            const Expanded(child: Text('Príjem za deň')),
            Text(
              '${calories.round()} kcal',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _NutrientChip(label: 'Bielkoviny', value: protein, unit: 'g'),
            _NutrientChip(label: 'Sacharidy', value: carbs, unit: 'g'),
            _NutrientChip(label: 'Tuky', value: fat, unit: 'g'),
            _NutrientChip(label: 'Vláknina', value: fiber, unit: 'g'),
            _NutrientChip(label: 'Cukor', value: sugar, unit: 'g'),
            _NutrientChip(label: 'Soľ', value: salt, unit: 'g'),
          ],
        ),
      ],
    ),
  );
}

class _NutrientChip extends StatelessWidget {
  const _NutrientChip({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final double value;
  final String unit;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFF141815),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF2A3529)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF9AA59D), fontSize: 11),
        ),
        const SizedBox(height: 2),
        Text(
          _amount(value, unit),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ],
    ),
  );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message, this.action});
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF141815),
      border: Border.all(color: const Color(0xFF252C27)),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message, style: const TextStyle(color: Color(0xFF9AA59D))),
        if (action != null) action!,
      ],
    ),
  );
}

class _FoodTile extends StatelessWidget {
  const _FoodTile({required this.entry, required this.trailing});
  final DailyFoodEntry entry;
  final Widget trailing;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 6),
    child: ListTile(
      dense: true,
      leading: const CircleAvatar(
        radius: 17,
        backgroundColor: Color(0xFF202820),
        foregroundColor: Color(0xFFB8F36B),
        child: Icon(Icons.eco_outlined, size: 18),
      ),
      title: Text(
        entry.food.name,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${_amount(entry.quantity, entry.unit)}  ·  '
        '${_amount(entry.calories, 'kcal')}  ·  '
        'bielkoviny ${_amount(entry.protein, 'g')}  ·  '
        'sacharidy ${_amount(entry.carbs, 'g')}  ·  '
        'tuky ${_amount(entry.fat, 'g')}  ·  '
        'vláknina ${_amount(entry.fiber, 'g')}  ·  '
        'cukor ${_amount(entry.sugar, 'g')}  ·  '
        'soľ ${_amount(entry.salt, 'g')}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Color(0xFF929E95), fontSize: 11),
      ),
      trailing: trailing,
    ),
  );
}

String _amount(double? value, String unit) {
  if (value == null) return '—';
  final decimals = value == value.roundToDouble() ? 0 : 1;
  return '${value.toStringAsFixed(decimals).replaceAll('.', ',')} $unit';
}
