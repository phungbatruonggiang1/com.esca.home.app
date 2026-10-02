import 'package:flutter/material.dart';

import 'home_screen.dart';

void main() {
  runApp(const EscaHomeApp());
}

class EscaHomeApp extends StatelessWidget {
  const EscaHomeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF00B3A4),
      brightness: Brightness.dark,
    );

    return MaterialApp(
      title: 'ESCA Home',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF101418),
        cardTheme: CardThemeData(
          color: const Color(0xFF18202A),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
