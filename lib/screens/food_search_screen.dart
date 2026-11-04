import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'food_create_screen.dart';
import 'food_home_screen.dart';

class FoodSearchScreen extends StatefulWidget {
  const FoodSearchScreen({
    required this.onAddFood,
    required this.addedFoodIds,
    super.key,
  });

  final Future<void> Function(
    Food food,
    double quantity,
    String unit,
    String mealSection,
  )
  onAddFood;
  final Set<String> addedFoodIds;

  @override
  State<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends State<FoodSearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<Food> _foods = [];
  bool _loading = false;
  bool _adding = false;
  bool _searched = false;
  String? _error;
  String? _addingFoodId;
  int _searchVersion = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    _searchVersion++;
    if (query.trim().length < 2) {
      setState(() {
        _foods = [];
        _loading = false;
        _searched = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _foods = [];
      _loading = false;
      _searched = false;
      _error = null;
    });
    _debounce = Timer(const Duration(milliseconds: 300), _search);
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.length < 2) return;
    final searchVersion = ++_searchVersion;
    setState(() {
      _loading = true;
      _error = null;
      _searched = true;
    });
    try {
      final rows = await Supabase.instance.client
          .from('foods')
          .select(
            'id,name,calories,proteins,carbohydrates,fats,fiber,sugar,salt,is_liquid',
          )
          .ilike('name', '%$query%')
          .order('name')
          .limit(40);
      if (!mounted || searchVersion != _searchVersion) return;
      setState(() {
        _foods = rows.map((row) => Food.fromMap(row)).toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted || searchVersion != _searchVersion) return;
      setState(() {
        _foods = [];
        _loading = false;
        _error = 'Vyhľadávanie sa nepodarilo. Skúste to znova.';
      });
    }
  }

  Future<void> _add(Food food) async {
    if (_adding) return;
    final details = await _askFoodDetails(food);
    if (details == null || !mounted) return;
    setState(() {
      _adding = true;
      _addingFoodId = food.id;
    });
    try {
      await widget.onAddFood(food, details.$1, details.$2, details.$3);
      if (!mounted) return;
      widget.addedFoodIds.add(food.id);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Pridané: ${food.name}')));
      setState(() {
        _adding = false;
        _addingFoodId = null;
      });
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _adding = false;
        _addingFoodId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jedlo sa nepodarilo pridať.')),
      );
    }
  }

  Future<void> _createFood() async {
    final food = await Navigator.of(context).push<Food>(
      MaterialPageRoute(
        builder: (_) => FoodCreateScreen(initialName: _controller.text.trim()),
      ),
    );
    if (food == null || !mounted) return;
    setState(() {
      if (!_foods.any((item) => item.id == food.id)) {
        _foods = [food, ..._foods];
      }
      _searched = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Nová potravina „${food.name}“ bola uložená.')),
    );
    await _add(food);
  }

  Future<(double, String, String)?> _askFoodDetails(Food food) async {
    final controller = TextEditingController(text: '100');
    var unit = food.isLiquid ? 'ml' : 'g';
    var mealSection = 'lunch';
    try {
      return await showDialog<(double, String, String)>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Zadajte množstvo'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(food.name),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: mealSection,
                  decoration: const InputDecoration(
                    labelText: 'Sekcia jedla',
                    border: OutlineInputBorder(),
                  ),
                  items: mealSections.entries
                      .map(
                        (section) => DropdownMenuItem(
                          value: section.key,
                          child: Text(section.value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => mealSection = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Množstvo',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<String>(
                      value: unit,
                      items: const [
                        DropdownMenuItem(value: 'g', child: Text('g')),
                        DropdownMenuItem(value: 'ml', child: Text('ml')),
                      ],
                      onChanged: (value) {
                        if (value != null) setDialogState(() => unit = value);
                      },
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Zrušiť'),
              ),
              FilledButton(
                onPressed: () {
                  final quantity = double.tryParse(
                    controller.text.trim().replaceAll(',', '.'),
                  );
                  if (quantity == null || !quantity.isFinite || quantity <= 0) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text('Zadajte množstvo väčšie ako nula.'),
                      ),
                    );
                    return;
                  }
                  Navigator.pop(dialogContext, (quantity, unit, mealSection));
                },
                child: const Text('Pridať'),
              ),
            ],
          ),
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pridať jedlo')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: TextField(
            controller: _controller,
            autofocus: true,
            onChanged: _onQueryChanged,
            onSubmitted: (_) {
              _debounce?.cancel();
              _search();
            },
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Hľadať potravinu',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Vymazať vyhľadávanie',
                      onPressed: () {
                        _controller.clear();
                        _onQueryChanged('');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
        ),
        Expanded(child: _buildResults()),
      ],
    ),
  );

  Widget _buildResults() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _search,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Skúsiť znova'),
            ),
          ],
        ),
      );
    }
    if (!_searched) {
      return const _SearchHint(
        icon: Icons.manage_search_rounded,
        message: 'Napíšte aspoň 2 znaky názvu potraviny.',
      );
    }
    if (_foods.isEmpty) {
      return _SearchHint(
        icon: Icons.search_off_rounded,
        message: 'Nenašli sa žiadne potraviny.',
        action: FilledButton.icon(
          onPressed: _createFood,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Pridať novú položku'),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        ..._foods.map((food) {
          final alreadyAdded = widget.addedFoodIds.contains(food.id);
          final isAdding = _addingFoodId == food.id;
          return Card(
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
                food.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                _nutrition(food),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF929E95), fontSize: 11),
              ),
              trailing: alreadyAdded
                  ? const Icon(Icons.check_circle_outline_rounded)
                  : IconButton(
                      tooltip: 'Pridať ${food.name}',
                      onPressed: _adding ? null : () => _add(food),
                      icon: isAdding
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_circle_outline_rounded),
                    ),
            ),
          );
        }),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _createFood,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Pridať novú položku'),
        ),
      ],
    );
  }
}

class _SearchHint extends StatelessWidget {
  const _SearchHint({required this.icon, required this.message, this.action});
  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: const Color(0xFF7E8981)),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF9AA59D)),
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    ),
  );
}

String _nutrition(Food food) =>
    'na 100 g: ${_amount(food.calories, 'kcal')}  ·  '
    'bielkoviny ${_amount(food.protein, 'g')}  ·  '
    'sacharidy ${_amount(food.carbs, 'g')}  ·  '
    'tuky ${_amount(food.fat, 'g')}  ·  '
    'vláknina ${_amount(food.fiber, 'g')}  ·  '
    'cukor ${_amount(food.sugar, 'g')}  ·  '
    'soľ ${_amount(food.salt, 'g')}';

String _amount(double? value, String unit) {
  if (value == null) return '—';
  final decimals = value == value.roundToDouble() ? 0 : 1;
  return '${value.toStringAsFixed(decimals).replaceAll('.', ',')} $unit';
}
