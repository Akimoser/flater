import 'package:flutter/material.dart';

import 'src/dependencies.dart';
import 'src/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  runApp(const FlaterApp());
}

class FlaterApp extends StatelessWidget {
  const FlaterApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Wild Atlas',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF165C43)),
      scaffoldBackgroundColor: const Color(0xFFF5F6F0),
      appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFF5F6F0)),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    home: const HomePage(),
  );
}
