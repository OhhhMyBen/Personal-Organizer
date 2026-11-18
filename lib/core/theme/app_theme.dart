import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class AppColors {
  AppColors._();

  static const Color scaffoldBg = Color(0xFF121417);
  static const Color cardBg = Color(0xFF1E2229);
  static const Color cardElevated = Color(0xFF262B34);
  static const Color inputBg = Color(0xFF16191F);
  static const Color borderSubtle = Color(0xFF2E3440);

  static const Color emerald = Color(0xFF10B981); // Budget
  static const Color amber = Color(0xFFF59E0B); // Bills / Alerts
  static const Color red = Color(0xFFEF4444); // Urgent / Overdue
  static const Color electricBlue = Color(0xFF3B82F6); // Calendar / Tasks
  static const Color purple = Color(0xFF8B5CF6); // Account Vault

  static const Color textPrimary = Color(0xFFF3F4F6);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textMuted = Color(0xFF6B7280);
}

String formatCurrency(double amount, {bool showDecimals = true}) {
  final formatter = NumberFormat.currency(
    locale: 'en_PH',
    symbol: '₱',
    decimalDigits: showDecimals ? 2 : 0,
  );
  return formatter.format(amount);
}

class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);
    final fontFamily = GoogleFonts.plusJakartaSans().fontFamily;
    final textTheme = base.textTheme.apply(
      fontFamily: fontFamily,
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.scaffoldBg,
      cardColor: AppColors.cardBg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.electricBlue,
        secondary: AppColors.emerald,
        tertiary: AppColors.purple,
        error: AppColors.red,
        surface: AppColors.cardBg,
        onSurface: AppColors.textPrimary,
      ),
      textTheme: textTheme,
      cardTheme: CardThemeData(
        color: AppColors.cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderSubtle, width: 0.6),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.scaffoldBg,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.cardElevated,
        contentTextStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  static ThemeData get lightTheme {
    final base = ThemeData.light(useMaterial3: true);
    final fontFamily = GoogleFonts.plusJakartaSans().fontFamily;
    final textTheme = base.textTheme.apply(
      fontFamily: fontFamily,
      bodyColor: const Color(0xFF111827),
      displayColor: const Color(0xFF111827),
    );

    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFFF3F4F6),
      cardColor: Colors.white,
      colorScheme: const ColorScheme.light(
        primary: AppColors.electricBlue,
        secondary: AppColors.emerald,
        tertiary: AppColors.purple,
        error: AppColors.red,
        surface: Colors.white,
        onSurface: Color(0xFF111827),
      ),
      textTheme: textTheme,
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFFF3F4F6),
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF111827),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1F2937),
        contentTextStyle: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
