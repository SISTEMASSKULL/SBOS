/// bAuthDEV — App Root con tema oscuro profesional

import 'package:flutter/material.dart';
import 'screens/catalogo/catalogo_screen.dart';
import 'widgets/status_bar.dart';

class BauthDevApp extends StatelessWidget {
  const BauthDevApp({super.key});

  static const _primary = Color(0xFF00D4AA);
  static const _bg = Color(0xFF0A0E13);
  static const _surface = Color(0xFF0D1117);
  static const _card = Color(0xFF161B22);
  static const _border = Color(0xFF30363D);
  static const _text = Color(0xFFE6EDF3);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'bAuthDEV — SBOS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: _primary,
          secondary: _primary.withAlpha(180),
          surface: _surface,
          onPrimary: Colors.black,
          onSurface: _text,
          outline: _border,
        ),
        scaffoldBackgroundColor: _bg,
        cardTheme: CardThemeData(
          color: _card,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: _border, width: 1),
          ),
        ),
        appBarTheme: const AppBarTheme(backgroundColor: _surface, foregroundColor: _text, elevation: 0),
        dividerTheme: const DividerThemeData(color: _border, thickness: 1),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _bg,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: _border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: _primary, width: 2)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          isDense: true,
        ),
      ),
      home: const CatalogoScreen(),
    );
  }
}
