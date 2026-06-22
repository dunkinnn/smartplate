import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'features/auth/screens/login.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://cvaggakfqnmqmewiziwl.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN2YWdnYWtmcW5tcW1ld2l6aXdsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE4OTk3NzAsImV4cCI6MjA5NzQ3NTc3MH0.W9EkdJ_kG81Yfeq63wGFDSxlui8giGLL7jdQV9oZHmk',
  );

  runApp(const SmartPlateApp());
}

class SmartPlateApp extends StatelessWidget {
  const SmartPlateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Plate',
      home: LoginScreen(),
    );
  }
}
