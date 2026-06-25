import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Soft periwinkle + mint + blush — minimal, modern, cute light palette.
class AppColors {
  static const primary = Color(0xFF9B8CFF);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryContainer = Color(0xFFE8E4FF);
  static const onPrimaryContainer = Color(0xFF3D3566);

  static const secondary = Color(0xFF6EDDD6);
  static const onSecondary = Color(0xFF1A4A46);
  static const secondaryContainer = Color(0xFFD4F7F3);
  static const onSecondaryContainer = Color(0xFF1F4E4A);

  static const tertiary = Color(0xFFFFB8D0);
  static const onTertiary = Color(0xFF5C2A3D);
  static const tertiaryContainer = Color(0xFFFFE4EE);
  static const onTertiaryContainer = Color(0xFF5C2A3D);

  static const background = Color(0xFFF3F1FA);
  static const onBackground = Color(0xFF3D3A5C);

  static const surface = Color(0xFFFFFFFF);
  static const onSurface = Color(0xFF3D3A5C);
  static const surfaceContainerLow = Color(0xFFF5F3FF);
  static const surfaceContainer = Color(0xFFF0EEFF);
  static const surfaceContainerHigh = Color(0xFFE8E4FF);
  static const onSurfaceVariant = Color(0xFF7A7794);

  static const outline = Color(0xFFE4E0F5);
  static const outlineVariant = Color(0xFFF0EDFA);
  static const shadow = Color(0x1A9B8CFF);

  static const error = Color(0xFFFF8A9B);
  static const onError = Color(0xFFFFFFFF);
  static const errorContainer = Color(0xFFFFE8EC);
  static const onErrorContainer = Color(0xFF6B2A35);

  // Dark palette — soft violet-tinted (readable, not pure black)
  static const darkBackground = Color(0xFF12101C);
  static const darkSurface = Color(0xFF1C1A2B);
  static const darkSurfaceHigh = Color(0xFF28253D);
  static const darkOnSurface = Color(0xFFECEAF8);
  static const darkOnSurfaceVariant = Color(0xFFA9A5C0);
}

class AppTheme {
  static const _radius = 16.0;
  static const _radiusLarge = 22.0;

  static TextTheme _textTheme(Brightness brightness) {
    final base = brightness == Brightness.light
        ? ThemeData.light().textTheme
        : ThemeData.dark().textTheme;
    return GoogleFonts.plusJakartaSansTextTheme(base).apply(
      bodyColor: brightness == Brightness.light ? AppColors.onSurface : Colors.white,
      displayColor: brightness == Brightness.light ? AppColors.onSurface : Colors.white,
    );
  }

  static InputDecorationTheme _inputTheme(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    return InputDecorationTheme(
      filled: true,
      fillColor: isLight ? AppColors.surfaceContainerLow : AppColors.darkSurfaceHigh,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      hintStyle: TextStyle(color: isLight ? AppColors.onSurfaceVariant : Colors.white54),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: BorderSide(color: isLight ? AppColors.outline : Colors.transparent),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: BorderSide(color: isLight ? AppColors.outline : Colors.transparent),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: BorderSide(color: AppColors.primary.withValues(alpha: isLight ? 0.7 : 1), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: const BorderSide(color: AppColors.error),
      ),
    );
  }

  static CardThemeData _cardTheme(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    return CardThemeData(
      color: isLight ? AppColors.surface : AppColors.darkSurface,
      elevation: isLight ? 2 : 0,
      shadowColor: isLight ? AppColors.primary.withValues(alpha: 0.12) : AppColors.shadow,
      surfaceTintColor: Colors.transparent,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_radiusLarge),
        side: BorderSide(
          color: isLight ? AppColors.outline : Colors.white.withValues(alpha: 0.06),
          width: isLight ? 1.2 : 1,
        ),
      ),
    );
  }

  static ThemeData get light {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      primaryContainer: AppColors.primaryContainer,
      onPrimaryContainer: AppColors.onPrimaryContainer,
      secondary: AppColors.secondary,
      onSecondary: AppColors.onSecondary,
      secondaryContainer: AppColors.secondaryContainer,
      onSecondaryContainer: AppColors.onSecondaryContainer,
      tertiary: AppColors.tertiary,
      onTertiary: AppColors.onTertiary,
      tertiaryContainer: AppColors.tertiaryContainer,
      onTertiaryContainer: AppColors.onTertiaryContainer,
      error: AppColors.error,
      onError: AppColors.onError,
      errorContainer: AppColors.errorContainer,
      onErrorContainer: AppColors.onErrorContainer,
      surface: AppColors.surface,
      onSurface: AppColors.onSurface,
      onSurfaceVariant: AppColors.onSurfaceVariant,
      outline: AppColors.outline,
      outlineVariant: AppColors.outlineVariant,
      shadow: AppColors.shadow,
      scrim: Colors.black54,
      inverseSurface: AppColors.onSurface,
      onInverseSurface: AppColors.surface,
      inversePrimary: AppColors.primaryContainer,
      surfaceTint: AppColors.primary,
    );

    final textTheme = _textTheme(Brightness.light);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.onSurface,
        ),
      ),
      cardTheme: _cardTheme(Brightness.light),
      inputDecorationTheme: _inputTheme(Brightness.light),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.outline),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceContainer,
        selectedColor: AppColors.primaryContainer,
        labelStyle: textTheme.labelMedium,
        side: const BorderSide(color: AppColors.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.outlineVariant, thickness: 1),
      drawerTheme: const DrawerThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(_radiusLarge),
            bottomRight: Radius.circular(_radiusLarge),
          ),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(_radiusLarge)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radiusLarge)),
        titleTextStyle: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.onSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.onSurfaceVariant,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: AppColors.primaryContainer,
        ),
        labelStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelStyle: textTheme.labelLarge,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.primary),
      iconTheme: const IconThemeData(color: AppColors.onSurfaceVariant),
    );
  }

  static ThemeData get dark {
    final scheme = ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      primaryContainer: const Color(0xFF3D3568),
      onPrimaryContainer: const Color(0xFFE8E4FF),
      secondary: AppColors.secondary,
      onSecondary: AppColors.onSecondary,
      secondaryContainer: const Color(0xFF2A5A55),
      onSecondaryContainer: AppColors.secondaryContainer,
      tertiary: AppColors.tertiary,
      onTertiary: AppColors.onTertiary,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkOnSurface,
      onSurfaceVariant: AppColors.darkOnSurfaceVariant,
      outline: const Color(0xFF3F3B58),
      outlineVariant: const Color(0xFF2E2B42),
      error: AppColors.error,
      onError: AppColors.onError,
      surfaceContainerHighest: AppColors.darkSurfaceHigh,
    );

    final textTheme = _textTheme(Brightness.dark);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.darkBackground,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.darkSurface,
        foregroundColor: AppColors.darkOnSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.darkOnSurface,
        ),
      ),
      cardTheme: _cardTheme(Brightness.dark),
      inputDecorationTheme: _inputTheme(Brightness.dark),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.darkSurfaceHigh,
        selectedColor: const Color(0xFF3D3568),
        labelStyle: textTheme.labelMedium?.copyWith(color: AppColors.darkOnSurface),
        side: const BorderSide(color: Color(0xFF3F3B58)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFF2E2B42), thickness: 1),
      drawerTheme: const DrawerThemeData(
        backgroundColor: AppColors.darkSurface,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.darkSurface,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.darkSurfaceHigh,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.darkOnSurface,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.darkOnSurfaceVariant,
        textColor: AppColors.darkOnSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      iconTheme: const IconThemeData(color: AppColors.darkOnSurfaceVariant),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.primary),
    );
  }
}
