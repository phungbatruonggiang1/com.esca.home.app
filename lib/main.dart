import 'package:flutter/material.dart';

import 'app_manager.dart';
import 'home_screen.dart';
import 'kit/theme.dart';

void main() {
  runApp(EscaHomeApp(controller: AppManagerController(DBusAppManagerBackend())));
}

class EscaHomeApp extends StatelessWidget {
  const EscaHomeApp({super.key, required this.controller});

  final AppManagerController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ESCA Home',
      debugShowCheckedModeBanner: false,
      theme: escaTheme(),
      home: HomeScreen(controller: controller),
    );
  }
}
