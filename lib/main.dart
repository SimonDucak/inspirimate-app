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
    title: 'Potravinový denník',
    debugShowCheckedModeBanner: false,
    locale: const Locale('sk'),
    supportedLocales: const [Locale('sk')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: const Color(0xFFB8F36B),
            brightness: Brightness.dark,
            surface: const Color(0xFF141815),
          ).copyWith(
            primary: const Color(0xFFB8F36B),
            onPrimary: const Color(0xFF17200F),
            secondary: const Color(0xFF8EDCC2),
            surface: const Color(0xFF141815),
            onSurface: const Color(0xFFE9EEE9),
            outline: const Color(0xFF303832),
          ),
      scaffoldBackgroundColor: const Color(0xFF0B0E0C),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0B0E0C),
        foregroundColor: Color(0xFFE9EEE9),
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: Color(0xFFE9EEE9),
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF141815),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFF252C27)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF141815),
        hintStyle: const TextStyle(color: Color(0xFF7E8981), fontSize: 14),
        prefixIconColor: const Color(0xFF8D9990),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF303832)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF252C27)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFB8F36B), width: 1.3),
        ),
      ),
    ),
    home: const AuthGate(),
  );
}
