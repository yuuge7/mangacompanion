import 'package:flutter/material.dart';

abstract class AppColors {
  static const bg = Color(0xFF09090B);
  static const card = Color(0xFF18181B);
  static const cardBorder = Color(0xFF27272A);
  static const field = Color(0xFF27272A);
  static const fieldBorder = Color(0xFF3F3F46);
  static const accent = Color(0xFFF97316);
  static const accentSoft = Color(0xFFFB923C);
  static const text = Color(0xFFF4F4F5);
  static const textDim = Color(0xFFA1A1AA);
  static const textFaint = Color(0xFF71717A);
  static const textGhost = Color(0xFF52525B);
  static const danger = Color(0xFFF87171);
  static const success = Color(0xFF4ADE80);
}

ThemeData buildTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accent,
      secondary: AppColors.accentSoft,
      surface: AppColors.card,
      onSurface: AppColors.text,
      error: AppColors.danger,
    ),
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.card,
      contentTextStyle: const TextStyle(color: AppColors.text),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.field,
      hintStyle: const TextStyle(color: AppColors.textGhost, fontSize: 14),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.fieldBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.accent),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
  );
}
