import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/auth_gate.dart';
import 'supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Mosuda',
    debugShowCheckedModeBanner: false,
    locale: const Locale('sk'),
    supportedLocales: const [Locale('sk')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: const Color(0xFF38D1BF),
            brightness: Brightness.dark,
            surface: const Color(0xFF111A18),
          ).copyWith(
            primary: const Color(0xFF38D1BF),
            onPrimary: const Color(0xFF061A18),
            secondary: const Color(0xFF8FE8DB),
            surface: const Color(0xFF111A18),
            onSurface: const Color(0xFFE8F1EF),
            outline: const Color(0xFF30413D),
          ),
      scaffoldBackgroundColor: const Color(0xFF080D0C),
      fontFamily: 'sans-serif',
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(fontSize: 15, height: 1.45),
        bodyMedium: TextStyle(fontSize: 14, height: 1.4),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF080D0C),
        foregroundColor: Color(0xFFE8F1EF),
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: Color(0xFFE8F1EF),
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF111A18),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFF22332F)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF111A18),
        hintStyle: const TextStyle(color: Color(0xFF849590), fontSize: 14),
        prefixIconColor: const Color(0xFF9AACA7),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF30413D)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF22332F)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF38D1BF), width: 1.5),
        ),
      ),
    ),
    home: const AuthGate(),
  );
}
