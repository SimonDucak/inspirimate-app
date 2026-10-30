import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Potravinový denník',
    debugShowCheckedModeBanner: false,
    locale: const Locale('sk'),
    supportedLocales: const [Locale('sk')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF426B4F),
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFF6F7F2),
    ),
    home: const FoodHomePage(),
  );
}

class Food {
  const Food({
    required this.id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  final int id;
  final String name;
  final double? calories;
  final double? protein;
  final double? carbs;
  final double? fat;

  factory Food.fromMap(Map<String, Object?> row) => Food(
    id: row['id'] as int,
    name: row['name'] as String,
    calories: (row['calories'] as num?)?.toDouble(),
    protein: (row['protein'] as num?)?.toDouble(),
    carbs: (row['carbs'] as num?)?.toDouble(),
    fat: (row['fat'] as num?)?.toDouble(),
  );
}

/// SQLite storage for the catalogue and the user's current food list.
/// Replace [seedFoods] with the provided catalogue records when available.
class FoodDatabase {
  FoodDatabase._();
  static final FoodDatabase instance = FoodDatabase._();

  Database? _database;

  Future<Database> get database async {
    if (_database case final existing?) return existing;
    if (kIsWeb) databaseFactory = databaseFactoryFfiWeb;
    final db = await openDatabase(
      kIsWeb
          ? 'food_journal.db'
          : p.join(await getDatabasesPath(), 'food_journal.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE foods (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            calories REAL,
            protein REAL,
            carbs REAL,
            fat REAL,
            extra_data TEXT,
            serving_sizes TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE selected_foods (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            food_id INTEGER NOT NULL,
            added_at TEXT NOT NULL,
            FOREIGN KEY(food_id) REFERENCES foods(id)
          )
        ''');
      },
    );
    final foodCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM foods'),
    );
    if (foodCount == 0) {
      final batch = db.batch();
      for (final food in seedFoods) {
        batch.insert('foods', food);
      }
      await batch.commit(noResult: true);
    } else {
      final batch = db.batch();
      for (final translation in foodNameTranslations.entries) {
        batch.update(
          'foods',
          {'name': translation.value},
          where: 'name = ?',
          whereArgs: [translation.key],
        );
      }
      await batch.commit(noResult: true);
    }
    _database = db;
    return db;
  }

  Future<List<Food>> getFoods() async {
    final rows = await (await database).query(
      'foods',
      orderBy: 'name COLLATE NOCASE',
    );
    return rows.map(Food.fromMap).toList();
  }

  Future<List<Food>> getSelectedFoods() async {
    final rows = await (await database).rawQuery('''
      SELECT foods.* FROM selected_foods
      JOIN foods ON foods.id = selected_foods.food_id
      ORDER BY selected_foods.id DESC
    ''');
    return rows.map(Food.fromMap).toList();
  }

  Future<void> addFood(Food food) async {
    await (await database).insert('selected_foods', {
      'food_id': food.id,
      'added_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> removeFood(Food food) async {
    final db = await database;
    final rows = await db.query(
      'selected_foods',
      columns: ['id'],
      where: 'food_id = ?',
      whereArgs: [food.id],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (rows.isNotEmpty) {
      await db.delete(
        'selected_foods',
        where: 'id = ?',
        whereArgs: [rows.first['id']],
      );
    }
  }
}

// Približné nutričné hodnoty na 100 g pre úvodný katalóg.
const Map<String, String> foodNameTranslations = {
  'Chicken breast': 'Kuracie prsia',
  'Rolled oats': 'Ovsené vločky',
  'Cooked rice': 'Varená ryža',
  'Egg': 'Vajce',
  'Banana': 'Banán',
  'Apple': 'Jablko',
  'Salmon': 'Losos',
  'Cooked lentils': 'Varená šošovica',
  'Greek yogurt': 'Grécky jogurt',
  'Avocado': 'Avokádo',
  'Boiled potato': 'Varené zemiaky',
  'Broccoli': 'Brokolica',
};

const List<Map<String, Object?>> seedFoods = [
  {
    'id': 1,
    'name': 'Kuracie prsia',
    'calories': 165,
    'protein': 31,
    'carbs': 0,
    'fat': 3.6,
  },
  {
    'id': 2,
    'name': 'Ovsené vločky',
    'calories': 389,
    'protein': 16.9,
    'carbs': 66.3,
    'fat': 6.9,
  },
  {
    'id': 3,
    'name': 'Varená ryža',
    'calories': 130,
    'protein': 2.7,
    'carbs': 28,
    'fat': 0.3,
  },
  {
    'id': 4,
    'name': 'Vajce',
    'calories': 155,
    'protein': 13,
    'carbs': 1.1,
    'fat': 11,
  },
  {
    'id': 5,
    'name': 'Banán',
    'calories': 89,
    'protein': 1.1,
    'carbs': 22.8,
    'fat': 0.3,
  },
  {
    'id': 6,
    'name': 'Jablko',
    'calories': 52,
    'protein': 0.3,
    'carbs': 13.8,
    'fat': 0.2,
  },
  {
    'id': 7,
    'name': 'Losos',
    'calories': 208,
    'protein': 20.4,
    'carbs': 0,
    'fat': 13.4,
  },
  {
    'id': 8,
    'name': 'Varená šošovica',
    'calories': 116,
    'protein': 9,
    'carbs': 20,
    'fat': 0.4,
  },
  {
    'id': 9,
    'name': 'Grécky jogurt',
    'calories': 97,
    'protein': 9,
    'carbs': 3.9,
    'fat': 5,
  },
  {
    'id': 10,
    'name': 'Avokádo',
    'calories': 160,
    'protein': 2,
    'carbs': 8.5,
    'fat': 14.7,
  },
  {
    'id': 11,
    'name': 'Varené zemiaky',
    'calories': 87,
    'protein': 1.9,
    'carbs': 20.1,
    'fat': 0.1,
  },
  {
    'id': 12,
    'name': 'Brokolica',
    'calories': 34,
    'protein': 2.8,
    'carbs': 6.6,
    'fat': 0.4,
  },
];

class FoodHomePage extends StatefulWidget {
  const FoodHomePage({super.key});

  @override
  State<FoodHomePage> createState() => _FoodHomePageState();
}

class _FoodHomePageState extends State<FoodHomePage> {
  final _searchController = TextEditingController();
  List<Food> _foods = [];
  List<Food> _selected = [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final foods = await FoodDatabase.instance.getFoods();
      final selected = await FoodDatabase.instance.getSelectedFoods();
      if (mounted) {
        setState(() {
          _foods = foods;
          _selected = selected;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Databázu potravín sa nepodarilo otvoriť: $error')),
        );
      }
    }
  }

  Future<void> _add(Food food) async {
    await FoodDatabase.instance.addFood(food);
    await _load();
  }

  Future<void> _remove(Food food) async {
    await FoodDatabase.instance.removeFood(food);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _foods
        .where((food) => food.name.toLowerCase().contains(_query))
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Potravinový denník',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Text(
                  'Zostavte si jedlo, jednu potravinu po druhej.',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Vyberte potravinu z katalógu a pridajte ju do svojho zoznamu.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: Colors.black54),
                ),
                const SizedBox(height: 24),
                _SectionTitle(title: 'VÁŠ ZOZNAM', count: _selected.length),
                const SizedBox(height: 10),
                if (_selected.isEmpty)
                  const _EmptyCard(
                    message:
                        'Zoznam je zatiaľ prázdny. Začnite výberom potraviny nižšie.',
                  )
                else
                  ..._selected.map(
                    (food) => _FoodTile(
                      food: food,
                      trailing: IconButton(
                        tooltip: 'Odstrániť: ${food.name}',
                        onPressed: () => _remove(food),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ),
                  ),
                const SizedBox(height: 26),
                _SectionTitle(title: 'KATALÓG POTRAVÍN', count: _foods.length),
                const SizedBox(height: 10),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Hľadať potraviny',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (filtered.isEmpty)
                  _EmptyCard(
                    message: _foods.isEmpty
                        ? 'V databáze zatiaľ nie sú žiadne potraviny.'
                        : 'Vyhľadávaniu nezodpovedajú žiadne potraviny.',
                  )
                else
                  ...filtered.map(
                    (food) => _FoodTile(
                      food: food,
                      trailing: IconButton.filledTonal(
                        tooltip: 'Pridať: ${food.name}',
                        onPressed: () => _add(food),
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.count});
  final String title;
  final int count;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
          fontSize: 12,
        ),
      ),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFE4EBDD),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '$count',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        ),
      ),
    ],
  );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Text(message, style: const TextStyle(color: Colors.black54)),
  );
}

class _FoodTile extends StatelessWidget {
  const _FoodTile({required this.food, required this.trailing});
  final Food food;
  final Widget trailing;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    color: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFEAF0E6),
        foregroundColor: const Color(0xFF426B4F),
        child: const Icon(Icons.eco_outlined),
      ),
      title: Text(
        food.name,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(_nutrition(food)),
      trailing: trailing,
    ),
  );
}

String _nutrition(Food food) {
  String value(double? amount, String unit) {
    if (amount == null) return '—';
    final decimals = amount == amount.roundToDouble() ? 0 : 1;
    final formatted = amount.toStringAsFixed(decimals).replaceAll('.', ',');
    return '$formatted $unit';
  }

  return 'na 100 g: ${value(food.calories, 'kcal')}  ·  '
      'bielkoviny ${value(food.protein, 'g')}  ·  '
      'sacharidy ${value(food.carbs, 'g')}  ·  '
      'tuky ${value(food.fat, 'g')}';
}
