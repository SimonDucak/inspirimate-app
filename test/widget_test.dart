import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:client_app/screens/food_home_screen.dart';
import 'package:client_app/screens/login_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('zobrazuje formulár na prihlásenie', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Potravinový denník'), findsOneWidget);
    expect(find.text('E-mail'), findsOneWidget);
    expect(find.text('Heslo'), findsOneWidget);
    expect(find.text('Prihlásiť sa'), findsOneWidget);
    expect(find.text('Nemáte účet? Zaregistrujte sa'), findsOneWidget);
  });

  test('mapuje záznam katalógu Supabase na potravinu', () {
    final food = Food.fromMap({
      'id': '455FEF22-1C3A-11EE-A977-EBC882FB7939',
      'name': 'Banány',
      'calories': 93.71,
      'proteins': 0.98,
      'carbohydrates': 22.34,
      'fats': 0.2,
      'fiber': 2.4,
      'sugar': 12.2,
      'salt': 0.01,
      'is_liquid': true,
    });

    expect(food.id, '455FEF22-1C3A-11EE-A977-EBC882FB7939');
    expect(food.name, 'Banány');
    expect(food.calories, 93.71);
    expect(food.protein, 0.98);
    expect(food.carbs, 22.34);
    expect(food.fat, 0.2);
    expect(food.fiber, 2.4);
    expect(food.sugar, 12.2);
    expect(food.salt, 0.01);
    expect(food.isLiquid, isTrue);
  });

  test('mapuje záznam denníka na ID záznamu aj ID potraviny', () {
    final entry = DailyFoodEntry.fromMap({
      'id': 'entry-id',
      'food_id': 'food-id',
      'food_name': 'Jablko',
      'calories': 52,
      'proteins': 0.3,
      'carbohydrates': 13.8,
      'fats': 0.2,
      'fiber': 2.4,
      'sugar': 10.3,
      'salt': 0.01,
      'quantity': 150,
      'unit': 'g',
      'meal_section': 'breakfast',
    });

    expect(entry.id, 'entry-id');
    expect(entry.food.id, 'food-id');
    expect(entry.food.name, 'Jablko');
    expect(entry.food.calories, 52);
    expect(entry.quantity, 150);
    expect(entry.unit, 'g');
    expect(entry.mealSection, 'breakfast');
    expect(entry.calories, 78);
    expect(entry.protein, closeTo(0.45, 0.0001));
    expect(entry.fiber, closeTo(3.6, 0.0001));
    expect(entry.sugar, closeTo(15.45, 0.0001));
    expect(entry.salt, closeTo(0.015, 0.0001));
  });
}
