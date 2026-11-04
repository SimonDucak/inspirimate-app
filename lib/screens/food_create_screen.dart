import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'food_home_screen.dart';

class FoodCreateScreen extends StatefulWidget {
  const FoodCreateScreen({this.initialName = '', super.key});

  final String initialName;

  @override
  State<FoodCreateScreen> createState() => _FoodCreateScreenState();
}

class _FoodCreateScreenState extends State<FoodCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  final Map<String, TextEditingController> _nutrients = {
    'calories': TextEditingController(),
    'proteins': TextEditingController(),
    'carbohydrates': TextEditingController(),
    'fats': TextEditingController(),
    'fiber': TextEditingController(),
    'sugar': TextEditingController(),
    'salt': TextEditingController(),
  };
  bool _isLiquid = false;
  bool _saving = false;

  static const _nutrientFields = <(String, String, String)>[
    ('calories', 'Energia', 'kcal'),
    ('proteins', 'Bielkoviny', 'g'),
    ('carbohydrates', 'Sacharidy', 'g'),
    ('fats', 'Tuky', 'g'),
    ('fiber', 'Vláknina', 'g'),
    ('sugar', 'Cukor', 'g'),
    ('salt', 'Soľ', 'g'),
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final controller in _nutrients.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _validateNumber(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = double.tryParse(value.trim().replaceAll(',', '.'));
    if (parsed == null || !parsed.isFinite || parsed < 0) {
      return 'Zadajte číslo 0 alebo väčšie.';
    }
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Na pridanie potraviny sa prihláste.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final values = <String, Object?>{
        'name': _nameController.text.trim(),
        'is_liquid': _isLiquid,
      };
      for (final field in _nutrientFields) {
        final input = _nutrients[field.$1]!.text.trim();
        values[field.$1] = input.isEmpty
            ? null
            : double.parse(input.replaceAll(',', '.'));
      }

      final row = await client.from('foods').insert(values).select().single();
      if (!mounted) return;
      Navigator.of(context).pop(Food.fromMap(row));
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Potravinu sa nepodarilo uložiť. Skúste to znova.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Nová potravina')),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _nameController,
            autofocus: widget.initialName.isEmpty,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Názov potraviny *',
              border: OutlineInputBorder(),
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Zadajte názov potraviny.'
                : null,
          ),
          const SizedBox(height: 16),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Tekutina'),
            subtitle: Text(
              _isLiquid ? 'Hodnoty na 100 ml' : 'Hodnoty na 100 g',
            ),
            value: _isLiquid,
            onChanged: (value) => setState(() => _isLiquid = value),
          ),
          const SizedBox(height: 8),
          const Text(
            'Nutričné hodnoty na 100 g/ml',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 12),
          ..._nutrientFields.map(
            (field) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextFormField(
                controller: _nutrients[field.$1],
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: _validateNumber,
                decoration: InputDecoration(
                  labelText: field.$2,
                  suffixText: field.$3,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Ukladá sa…' : 'Uložiť potravinu'),
          ),
        ],
      ),
    ),
  );
}
