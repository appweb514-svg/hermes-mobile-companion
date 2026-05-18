import 'package:flutter/material.dart';
import 'features/home/home_screen.dart';
import 'shared/theme/app_theme.dart';

class HermesMobileApp extends StatelessWidget {
  const HermesMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hermes Mobile',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
