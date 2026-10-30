import 'package:flutter_test/flutter_test.dart';

import 'package:client_app/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('zobrazuje denník a úvodné nutričné údaje', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Potravinový denník'), findsOneWidget);
    expect(find.text('VÁŠ ZOZNAM'), findsOneWidget);
    expect(find.text('KATALÓG POTRAVÍN'), findsOneWidget);
    expect(seedFoods, hasLength(12));
    expect(seedFoods.first['name'], 'Kuracie prsia');
    expect(seedFoods.first['calories'], 165);
    expect(seedFoods.first['protein'], 31);
    expect(find.textContaining('counter'), findsNothing);
  });
}
