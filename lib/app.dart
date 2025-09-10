import 'package:flutter/material.dart';

import 'ui/vault_home_page.dart';

class DataMaskingApp extends StatelessWidget {
  const DataMaskingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Data Masking Vault',
      debugShowCheckedModeBanner: false,
      theme: _greenBlackTheme(),
      home: const VaultHomePage(),
    );
  }
}

/// Green + black (dark) theme.
///
/// Notes:
/// - Uses Material 3 dark color scheme.
/// - Keeps surfaces near-black and primary as a vivid green.
ThemeData _greenBlackTheme() {
  const bg = Color(0xFF0B0B0B);
  const surface = Color(0xFF111111);
  const surface2 = Color(0xFF171717);
  const green = Color(0xFF1DB954); // vivid green
  const text = Color(0xFFECECEC);
  const muted = Color(0xFFB3B3B3);

  final base = ThemeData.dark(useMaterial3: true);

  final scheme = ColorScheme.fromSeed(
    seedColor: green,
    brightness: Brightness.dark,
  ).copyWith(
    primary: green,
    secondary: green,
    background: bg,
    surface: surface,
    onPrimary: Colors.black,
    onSurface: text,
    onBackground: text,
  );

  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: bg,
      foregroundColor: text,
      elevation: 0,
    ),

    // ✅ FIX: use CardThemeData (not CardTheme)
    cardTheme: CardThemeData(
      margin: EdgeInsets.zero,
      color: surface2,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface2,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      hintStyle: const TextStyle(color: muted),
      labelStyle: const TextStyle(color: muted),
    ),
    textTheme: base.textTheme.copyWith(
      headlineMedium: const TextStyle(
        color: text,
        fontWeight: FontWeight.w800,
      ),
      titleMedium: const TextStyle(
        color: text,
        fontWeight: FontWeight.w700,
      ),
      bodyMedium: const TextStyle(color: text),
      bodySmall: const TextStyle(color: muted),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: surface2,
      contentTextStyle: TextStyle(color: text),
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFF2A2A2A)),
  );
}
