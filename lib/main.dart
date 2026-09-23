import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'features/auth/screens/login.dart';
import 'features/auth/screens/client/dashboard.dart';
import 'features/auth/screens/splash.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://cvaggakfqnmqmewiziwl.supabase.co',
    publishableKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN2YWdnYWtmcW5tcW1ld2l6aXdsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE4OTk3NzAsImV4cCI6MjA5NzQ3NTc3MH0.W9EkdJ_kG81Yfeq63wGFDSxlui8giGLL7jdQV9oZHmk',
  );

  runApp(const SmartPlateApp());
}

class SmartPlateApp extends StatelessWidget {
  const SmartPlateApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Supabase keeps the session on the device, so signed-in users skip Login.
    final signedIn = Supabase.instance.client.auth.currentSession != null;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Plate',
      // Honours the phone's font size but caps it so layouts do not break.
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(
              minScaleFactor: 0.9,
              maxScaleFactor: 1.2,
            ),
          ),
          child: child!,
        );
      },
      // Animated intro, then Home or Login.
      home: SplashScreen(
        next: signedIn ? const DashboardScreen() : const LoginScreen(),
      ),
    );
  }
}
