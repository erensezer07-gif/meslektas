import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ============================================================
// Tasarım sisteminin tek doğru kaynağı.
// Ekran kodunda sabit renk, fontSize veya boşluk yazılmaz;
// her şey buradan gelir.
// ============================================================

/// Renk paleti: tek vurgu rengi (indigo) + zengin nötr griler.
abstract final class AppColors {
  // Vurgu (indigo)
  static const primary = Color(0xFF4F46E5);
  static const primaryHover = Color(0xFF4338CA); // basılı/hover tonu
  static const primarySurface = Color(
    0xFFEEF2FF,
  ); // açık indigo dolgu (seçili chip vb.)

  // Nötrler (koyudan açığa)
  static const textPrimary = Color(0xFF1E1B2E); // ana yazı
  static const textSecondary = Color(0xFF6B7280); // ikincil yazı
  static const textTertiary = Color(0xFF9CA3AF); // ipucu/placeholder
  static const border = Color(0xFFE5E7EB); // ince kenarlık
  static const surfaceSubtle = Color(0xFFF3F4F6); // hafif yüzey dolgusu
  static const background = Color(0xFFFAFAFA); // sayfa arka planı
  static const surface = Color(0xFFFFFFFF); // kart/yüzey

  // Durum renkleri
  static const success = Color(0xFF16A34A);
  static const successSurface = Color(0xFFF0FDF4);
  static const error = Color(0xFFDC2626);
  static const errorSurface = Color(0xFFFEF2F2);
}

/// Boşluk sabitleri (4'lü ölçek).
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Köşe yarıçapları.
abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double full = 999; // chip/avatar için tam yuvarlak
}

/// Animasyon süreleri — tasarım kuralı: 150-300 ms, amaçlı ve hızlı.
/// Ekranlar süreyi buradan alır; sabit Duration yazılmaz.
abstract final class AppDurations {
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 350);
}

/// Material 3 tema — Manrope tipografi + yukarıdaki palet.
abstract final class AppTheme {
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      error: AppColors.error,
      surface: AppColors.surface,
    );

    final textTheme = GoogleFonts.manropeTextTheme().apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: textTheme.copyWith(
        // Başlıklar: sıkı ve ağır
        headlineMedium: textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        // Gövde: rahat okunur
        bodyLarge: textTheme.bodyLarge?.copyWith(height: 1.5),
        bodyMedium: textTheme.bodyMedium?.copyWith(height: 1.5),
        bodySmall: textTheme.bodySmall?.copyWith(
          color: AppColors.textSecondary,
        ),
        // Etiket/buton yazıları
        labelLarge: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),

      // AppBar: düz, arka planla bütünleşik
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.manrope(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: -0.3,
        ),
      ),

      // Dolgulu buton: indigo, gölgesiz, rahat yükseklik
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.surfaceSubtle,
          disabledForegroundColor: AppColors.textTertiary,
          elevation: 0,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),

      // Kenarlıklı buton: ince gri kenarlık, koyu yazı
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.border),
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),

      // Yazı butonu: sade indigo
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
      ),

      // Form alanları: açık gri dolgu, ince kenarlık, odakta indigo
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceSubtle,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        hintStyle: const TextStyle(color: AppColors.textTertiary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
      ),

      // Chip: tam yuvarlak; seçilide açık indigo dolgu
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceSubtle,
        selectedColor: AppColors.primarySurface,
        checkmarkColor: AppColors.primary,
        labelStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
      ),

      // Kart/yüzey: gölge yok, ince kenarlık
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.border),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: GoogleFonts.manrope(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }
}
