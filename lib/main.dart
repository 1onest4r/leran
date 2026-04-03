import 'package:flutter/material.dart';
import 'package:leran/ui/styling/theme_palette.dart';
import 'package:leran/ui/styling/layout_manager.dart';

void main() => runApp(const LeranApp());

class LeranApp extends StatelessWidget {
  const LeranApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Leran',
      debugShowCheckedModeBanner: false,

      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,

      home: const LayoutManager(),
    );
  }
}
