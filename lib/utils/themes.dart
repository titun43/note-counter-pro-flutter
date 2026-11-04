import 'package:flutter/material.dart';
import 'constants.dart';

class AppThemes {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.bgLight,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bgLight,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: AppColors.bgCard,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.bgDark,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.bgCard,
        selectedItemColor: AppColors.primaryDark,
        unselectedItemColor: AppColors.textSecondary,
      ),
      // === PROFESSIONAL DIALOG THEME (v3.52.0) ===
      // Applied globally so ALL dialogs get instant upgrade.
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.bgCard,
        elevation: 16,
        shadowColor: AppColors.primary.withOpacity(0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: AppColors.bgDark,
          letterSpacing: -0.3,
        ),
        contentTextStyle: TextStyle(
          fontSize: 14,
          color: AppColors.textPrimary,
        ),
      ),
      // === PROFESSIONAL INPUT THEME ===
      // Underline style (modern) instead of full box border.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgLight.withOpacity(0.5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: TextStyle(
          color: AppColors.textSecondary.withOpacity(0.6),
          fontSize: 13,
        ),
        // Underline border (modern look)
        enabledBorder: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: AppColors.textSecondary.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        focusedBorder: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: AppColors.primary,
            width: 2,
          ),
        ),
        errorBorder: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.danger, width: 1.5),
        ),
        focusedErrorBorder: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.danger, width: 2),
        ),
      ),
      // === BUTTON THEMES ===
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: AppColors.bgDark,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bgDark,
        foregroundColor: AppColors.textPrimaryDark,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: AppColors.bgCardDark,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.bgDark,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.bgCardDark,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondaryDark,
      ),
      // === PROFESSIONAL DIALOG THEME (v3.52.0) ===
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.bgCardDark,
        elevation: 16,
        shadowColor: AppColors.primary.withOpacity(0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: -0.3,
        ),
        contentTextStyle: TextStyle(
          fontSize: 14,
          color: Colors.white70,
        ),
      ),
      // === PROFESSIONAL INPUT THEME ===
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: TextStyle(
          color: AppColors.textSecondaryDark,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: TextStyle(
          color: AppColors.textSecondaryDark.withOpacity(0.5),
          fontSize: 13,
        ),
        enabledBorder: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: AppColors.textSecondaryDark.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        focusedBorder: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: AppColors.primary,
            width: 2,
          ),
        ),
        errorBorder: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.danger, width: 1.5),
        ),
        focusedErrorBorder: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.danger, width: 2),
        ),
      ),
      // === BUTTON THEMES ===
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
