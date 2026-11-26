import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

class MonGarageApp extends StatelessWidget {
  const MonGarageApp({super.key});

  static const Color background = Color(0xFF07121D);
  static const Color surface = Color(0xFF122331);
  static const Color raised = Color(0xFF1A2D3A);
  static const Color accent = Color(0xFFA5D84D);
  static const Color textPrimary = Color(0xFFF4F7FA);
  static const Color textSecondary = Color(0xFFAAB9C5);
  static const Color outline = Color(0xFF304351);

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
      surface: surface,
      primary: accent,
      onPrimary: const Color(0xFF17220B),
      secondary: const Color(0xFF83B9C4),
      onSecondary: background,
      error: const Color(0xFFFF6B64),
      onSurface: textPrimary,
    );

    return MaterialApp(
      title: 'MON GARAGE',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: scheme,
        scaffoldBackgroundColor: background,
        canvasColor: surface,
        visualDensity: VisualDensity.standard,
        appBarTheme: const AppBarTheme(
          backgroundColor: background,
          foregroundColor: textPrimary,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.35),
        ),
        textTheme: const TextTheme(
          headlineSmall: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: textPrimary, letterSpacing: -0.6),
          titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary),
          titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textPrimary),
          bodyLarge: TextStyle(fontSize: 15, color: textPrimary),
          bodyMedium: TextStyle(fontSize: 13, color: textSecondary),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: raised,
          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
          labelStyle: const TextStyle(color: textSecondary),
          hintStyle: const TextStyle(color: textSecondary),
          prefixIconColor: textSecondary,
          suffixIconColor: textSecondary,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: outline)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: outline)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: accent, width: 1.6)),
        ),
        cardTheme: CardThemeData(
          color: surface,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: outline)),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: surface,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: const TextStyle(color: textPrimary, fontSize: 19, fontWeight: FontWeight.w800),
          contentTextStyle: const TextStyle(color: textSecondary, fontSize: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: outline)),
        ),
        listTileTheme: const ListTileThemeData(iconColor: textSecondary, textColor: textPrimary),
        dividerTheme: const DividerThemeData(color: outline, thickness: 1),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: const Color(0xFF17220B),
            minimumSize: const Size(48, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: accent,
            minimumSize: const Size(48, 48),
            side: const BorderSide(color: outline),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(backgroundColor: accent, foregroundColor: Color(0xFF17220B)),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: raised,
          contentTextStyle: const TextStyle(color: textPrimary),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13), side: const BorderSide(color: outline)),
        ),
        popupMenuTheme: const PopupMenuThemeData(color: surface, surfaceTintColor: Colors.transparent),
        progressIndicatorTheme: const ProgressIndicatorThemeData(color: accent),
      ),
      home: const HomeScreen(),
    );
  }
}
