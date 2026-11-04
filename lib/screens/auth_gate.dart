import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'food_home_screen.dart';
import 'login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
    stream: Supabase.instance.client.auth.onAuthStateChange,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (Supabase.instance.client.auth.currentSession != null) {
        return const FoodHomeScreen();
      }
      return const LoginScreen();
    },
  );
}
