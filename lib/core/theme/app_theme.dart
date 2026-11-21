import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_tokens.dart';

/// Design 2.0 «Samarqand»: Inter (bundled in `assets/fonts`, supports the
/// Uzbek ʻ U+02BB and Cyrillic), cream / night backgrounds, turquoise and
/// lapis brand, rounded 24 cards, large bold headings.
abstract final class AppTheme {
  /// Bundled font family (works offline).
  static const fontFamily = 'Inter';

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ColorScheme _scheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final seed = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
    );
    if (isDark) {
      return seed.copyWith(
        primary: const Color(0xFF2DD4CB),
        onPrimary: const Color(0xFF032826),
        primaryContainer: const Color(0xFF0D4744),
        onPrimaryContainer: const Color(0xFFB5F3EE),
        secondary: const Color(0xFF6E9BFF),
        onSecondary: const Color(0xFF081A4A),
        // Tonal buttons and selected chips use the turquoise tint.
        secondaryContainer: const Color(0xFF12403F),
        onSecondaryContainer: const Color(0xFFB5F3EE),
        tertiary: AppColors.saffron,
        onTertiary: const Color(0xFF2A1A00),
        tertiaryContainer: const Color(0xFF4A3407),
        onTertiaryContainer: const Color(0xFFFFE2A8),
        error: const Color(0xFFFB5374),
        onError: Colors.white,
        errorContainer: const Color(0xFF5C1325),
        onErrorContainer: const Color(0xFFFFD9DF),
        surface: AppColors.surfaceDark,
        onSurface: const Color(0xFFE8EDF5),
        onSurfaceVariant: const Color(0xFF9AA7BA),
        surfaceContainerLowest: const Color(0xFF080D18),
        surfaceContainerLow: const Color(0xFF101828),
        surfaceContainer: const Color(0xFF162033),
        surfaceContainerHigh: const Color(0xFF1B263B),
        surfaceContainerHighest: const Color(0xFF223049),
        outline: const Color(0xFF4A5A75),
        outlineVariant: const Color(0xFF24304A),
        inverseSurface: const Color(0xFFE8EDF5),
        onInverseSurface: AppColors.ink,
        inversePrimary: AppColors.primaryDeep,
        surfaceTint: Colors.transparent,
      );
    }
    return seed.copyWith(
      // Deep turquoise keeps white button text readable (WCAG AA).
      primary: AppColors.primaryDeep,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFCFF5F2),
      onPrimaryContainer: const Color(0xFF053F3C),
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFD5F4F1),
      onSecondaryContainer: const Color(0xFF064C48),
      tertiary: const Color(0xFFB86E00),
      onTertiary: Colors.white,
      tertiaryContainer: const Color(0xFFFDECC8),
      onTertiaryContainer: const Color(0xFF4A3000),
      error: AppColors.garnet,
      onError: Colors.white,
      errorContainer: const Color(0xFFFFE0E6),
      onErrorContainer: const Color(0xFF6B0020),
      surface: Colors.white,
      onSurface: AppColors.ink,
      onSurfaceVariant: const Color(0xFF5B6675),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xFFFCFAF6),
      surfaceContainer: const Color(0xFFF5F1EA),
      surfaceContainerHigh: const Color(0xFFEFEAE2),
      surfaceContainerHighest: const Color(0xFFE9E3DA),
      outline: const Color(0xFFB9B2A6),
      outlineVariant: const Color(0xFFECE6DC),
      inverseSurface: AppColors.ink,
      onInverseSurface: const Color(0xFFF3F1EC),
      inversePrimary: const Color(0xFF5EEAD4),
      surfaceTint: Colors.transparent,
    );
  }

  static TextTheme _text(TextTheme t, ColorScheme scheme) => t.copyWith(
    displayLarge: t.displayLarge?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -1.5,
    ),
    displayMedium: t.displayMedium?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -1.2,
    ),
    displaySmall: t.displaySmall?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -1,
    ),
    headlineLarge: t.headlineLarge?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.8,
    ),
    headlineMedium: t.headlineMedium?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.6,
    ),
    headlineSmall: t.headlineSmall?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.4,
    ),
    titleLarge: t.titleLarge?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
    ),
    titleMedium: t.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: -0.1,
    ),
    titleSmall: t.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    bodySmall: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
    labelLarge: t.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    labelMedium: t.labelMedium?.copyWith(fontWeight: FontWeight.w600),
  );

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = _scheme(brightness);
    final background = isDark ? AppColors.backgroundDark : AppColors.background;
    final radius = BorderRadius.circular(AppRadius.card);
    final inputRadius = BorderRadius.circular(AppRadius.input);

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: fontFamily,
    );
    final text = _text(base.textTheme, scheme);

    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.button),
    );
    const buttonText = TextStyle(
      fontFamily: fontFamily,
      fontSize: 15,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.1,
    );

    return base.copyWith(
      scaffoldBackgroundColor: background,
      canvasColor: background,
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        titleTextStyle: text.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 66,
        indicatorColor: AppColors.primary.withValues(
          alpha: isDark ? 0.22 : 0.14,
        ),
        indicatorShape: const StadiumBorder(),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: fontFamily,
            fontSize: 11.5,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: buttonShape,
          textStyle: buttonText,
          elevation: 0,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: buttonShape,
          textStyle: buttonText,
          elevation: 0,
          backgroundColor: scheme.surface,
          foregroundColor: scheme.primary,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: buttonShape,
          textStyle: buttonText,
          side: BorderSide(color: scheme.outlineVariant, width: 1.4),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: buttonText,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        focusElevation: 2,
        hoverElevation: 4,
        highlightElevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        extendedTextStyle: buttonText,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? scheme.surfaceContainer : scheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: scheme.outlineVariant, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: scheme.primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: scheme.error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: scheme.error, width: 1.8),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: text.labelLarge,
        backgroundColor: scheme.surface,
        selectedColor: scheme.secondaryContainer,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: scheme.secondaryContainer,
          selectedForegroundColor: scheme.onSecondaryContainer,
          side: BorderSide(color: scheme.outlineVariant),
          textStyle: text.labelLarge,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorColor: scheme.primary,
        labelStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelStyle: text.titleSmall,
        dividerColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark
            ? scheme.surfaceContainerHighest
            : AppColors.ink,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: isDark ? scheme.onSurface : Colors.white,
        ),
        actionTextColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: scheme.outline,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: text.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w800,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
        ),
        iconColor: scheme.onSurfaceVariant,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      switchTheme: SwitchThemeData(
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.transparent
              : scheme.outline,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.primary.withValues(alpha: 0.14),
        circularTrackColor: Colors.transparent,
        linearMinHeight: 6,
        borderRadius: BorderRadius.circular(99),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.primary,
        thumbColor: scheme.primary,
        inactiveTrackColor: AppColors.primary.withValues(alpha: 0.18),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? scheme.surfaceContainerHighest : AppColors.ink,
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: text.bodySmall?.copyWith(
          color: isDark ? scheme.onSurface : Colors.white,
        ),
      ),
    );
  }
}
