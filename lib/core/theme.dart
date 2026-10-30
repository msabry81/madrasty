import 'package:flutter/material.dart';

/// ألوان نظام التصميم (Modern Egyptian EdTech).
class AppColors {
  static const canvas = Color(0xFFFCF9F2);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceLow = Color(0xFFF6F3EC);
  static const surfaceMid = Color(0xFFF0EEE7);
  static const sand = Color(0xFFEFE9DB);
  static const border = Color(0xFFE2DAC8);
  static const primary = Color(0xFF005F56);
  static const primaryContainer = Color(0xFF0B7A6F);
  static const primaryTint = Color(0xFFD6F2EE);
  static const navy = Color(0xFF10263F);
  static const navyDeep = Color(0xFF051C35);
  static const amber = Color(0xFFF4B03E);
  static const onSurface = Color(0xFF1C1C18);
  static const onVariant = Color(0xFF3E4947);
  static const outline = Color(0xFF6E7977);

  static const successBg = Color(0xFFDCFCE7), successFg = Color(0xFF166534), successBorder = Color(0xFF86EFAC);
  static const warnBg = Color(0xFFFEF3C7), warnFg = Color(0xFF92400E), warnBorder = Color(0xFFFCD34D);
  static const infoBg = Color(0xFFEFF6FF), infoFg = Color(0xFF1E40AF), infoBorder = Color(0xFFBFDBFE);
  static const errorBg = Color(0xFFFEE2E2), errorFg = Color(0xFF991B1B), errorBorder = Color(0xFFFCA5A5);
}

const kHeadFont = 'Cairo';
const kBodyFont = 'Tajawal';

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.primary).copyWith(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    primaryContainer: AppColors.primaryTint,
    onPrimaryContainer: const Color(0xFF00201C),
    secondary: const Color(0xFF4B607B),
    secondaryContainer: const Color(0xFFC9DEFF),
    tertiary: const Color(0xFF734D00),
    tertiaryContainer: const Color(0xFFFFDDB0),
    error: const Color(0xFFB91C1C),
    errorContainer: AppColors.errorBg,
    surface: AppColors.canvas,
    onSurface: AppColors.onSurface,
    onSurfaceVariant: AppColors.onVariant,
    outline: AppColors.outline,
    outlineVariant: AppColors.border,
    surfaceContainerLow: AppColors.surfaceLow,
    surfaceContainerHighest: AppColors.surfaceMid,
  );

  final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: kBodyFont).textTheme;
  TextStyle? head(TextStyle? s, FontWeight w) => s?.copyWith(fontFamily: kHeadFont, fontWeight: w, color: AppColors.navy, height: 1.45);
  final text = base.copyWith(
    headlineLarge: head(base.headlineLarge, FontWeight.w800),
    headlineMedium: head(base.headlineMedium, FontWeight.w800),
    headlineSmall: head(base.headlineSmall, FontWeight.w700),
    titleLarge: head(base.titleLarge, FontWeight.w700),
    titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: AppColors.navy),
    titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: AppColors.navy),
    bodyLarge: base.bodyLarge?.copyWith(height: 1.65),
    bodyMedium: base.bodyMedium?.copyWith(height: 1.6),
    labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w700),
  );

  OutlineInputBorder border(Color c, [double w = 1.5]) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c, width: w));

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: kBodyFont,
    textTheme: text,
    scaffoldBackgroundColor: AppColors.canvas,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.canvas,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      foregroundColor: AppColors.navy,
      titleTextStyle: const TextStyle(fontFamily: kHeadFont, fontWeight: FontWeight.w700, fontSize: 20, color: AppColors.navy),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.sand, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceLow,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: border(AppColors.border),
      enabledBorder: border(AppColors.border),
      focusedBorder: border(AppColors.primaryContainer),
      errorBorder: border(const Color(0xFFB91C1C)),
      focusedErrorBorder: border(const Color(0xFFB91C1C)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontFamily: kBodyFont, fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.navy,
        minimumSize: const Size(0, 48),
        side: const BorderSide(color: AppColors.border, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontFamily: kBodyFont, fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontFamily: kBodyFont, fontWeight: FontWeight.w700),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceLow,
      selectedColor: AppColors.primaryTint,
      checkmarkColor: AppColors.primary,
      side: const BorderSide(color: AppColors.border),
      shape: const StadiumBorder(),
      labelStyle: const TextStyle(fontFamily: kBodyFont, fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.navy),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: AppColors.border)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.navy,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: AppColors.primaryTint,
        selectedForegroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.border),
      ),
    ),
  );
}
