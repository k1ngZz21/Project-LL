import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Shared radii and spacing so every screen uses the same rhythm.
abstract final class AppRadius {
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 28;
  static const double pill = 999;
}

abstract final class AppShadows {
  /// Soft, warm elevation for white cards on cream.
  static const card = [
    BoxShadow(
      color: Color(0x0F5A3A1A),
      blurRadius: 18,
      offset: Offset(0, 6),
    ),
    BoxShadow(
      color: Color(0x0A5A3A1A),
      blurRadius: 3,
      offset: Offset(0, 1),
    ),
  ];

  /// Stronger lift for hero and dark feature cards.
  static const raised = [
    BoxShadow(
      color: Color(0x295A3A1A),
      blurRadius: 24,
      offset: Offset(0, 10),
    ),
  ];
}

abstract final class AppTheme {
  /// The app font family. `null` uses the platform font (Roboto on Android).
  /// If the Nunito font is approved and bundled, set this to 'Nunito'.
  static const String? fontFamily = null;

  static final TextTheme _textTheme = const TextTheme(
    displaySmall: TextStyle(
      fontSize: 34,
      fontWeight: FontWeight.w800,
      height: 1.15,
      letterSpacing: -0.6,
    ),
    headlineLarge: TextStyle(
      fontSize: 30,
      fontWeight: FontWeight.w800,
      height: 1.18,
      letterSpacing: -0.5,
    ),
    headlineMedium: TextStyle(
      fontSize: 26,
      fontWeight: FontWeight.w800,
      height: 1.2,
      letterSpacing: -0.4,
    ),
    headlineSmall: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w800,
      height: 1.25,
      letterSpacing: -0.3,
    ),
    titleLarge: TextStyle(
      fontSize: 19,
      fontWeight: FontWeight.w800,
      height: 1.25,
      letterSpacing: -0.2,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      height: 1.3,
      letterSpacing: -0.1,
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      height: 1.3,
    ),
    bodyLarge: TextStyle(fontSize: 16, height: 1.55),
    bodyMedium: TextStyle(fontSize: 14.5, height: 1.5),
    bodySmall: TextStyle(fontSize: 12.5, height: 1.4),
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.1,
    ),
    labelMedium: TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
    ),
    labelSmall: TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.3,
    ),
  ).apply(
    fontFamily: fontFamily,
    bodyColor: AppColors.ink,
    displayColor: AppColors.ink,
  );

  static final RoundedRectangleBorder _pillShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.pill),
  );

  static const TextStyle _buttonLabel = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.1,
  );

  static OutlineInputBorder _inputBorder(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: color, width: width),
      );

  static final light = ThemeData(
    useMaterial3: true,
    fontFamily: fontFamily,
    colorScheme:
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.primary,
          onPrimary: AppColors.white,
          primaryContainer: AppColors.lightPink,
          onPrimaryContainer: AppColors.redDark,
          secondary: AppColors.gold,
          onSecondary: AppColors.darkBackground,
          secondaryContainer: AppColors.lightPink,
          onSecondaryContainer: AppColors.redDark,
          tertiary: AppColors.goldDeep,
          surface: AppColors.cream,
          onSurface: AppColors.ink,
          onSurfaceVariant: AppColors.inkSoft,
          surfaceTint: Colors.transparent,
          surfaceContainerLowest: AppColors.white,
          surfaceContainerLow: AppColors.white,
          surfaceContainer: AppColors.white,
          surfaceContainerHigh: AppColors.white,
          surfaceContainerHighest: AppColors.creamSecondary,
          outline: AppColors.border,
          outlineVariant: AppColors.borderSoft,
          error: AppColors.primary,
        ),
    scaffoldBackgroundColor: AppColors.cream,
    textTheme: _textTheme,
    splashFactory: InkRipple.splashFactory,
    visualDensity: VisualDensity.standard,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.cream,
      foregroundColor: AppColors.ink,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: false,
      elevation: 0,
      titleSpacing: 16,
      titleTextStyle: _textTheme.titleLarge?.copyWith(fontSize: 19),
    ),
    cardTheme: CardThemeData(
      color: AppColors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: const BorderSide(color: AppColors.borderSoft),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        disabledBackgroundColor: AppColors.creamSecondary,
        disabledForegroundColor: AppColors.gray,
        minimumSize: const Size(64, 52),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        textStyle: _buttonLabel,
        shape: _pillShape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        backgroundColor: AppColors.white,
        disabledForegroundColor: AppColors.gray,
        minimumSize: const Size(64, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        side: const BorderSide(color: AppColors.border, width: 1.5),
        textStyle: _buttonLabel,
        shape: _pillShape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        shape: _pillShape,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(64, 48)),
        textStyle: const WidgetStatePropertyAll(_buttonLabel),
        shape: WidgetStatePropertyAll(_pillShape),
        side: const WidgetStatePropertyAll(
          BorderSide(color: AppColors.border, width: 1.2),
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.darkBackground
              : AppColors.white,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.gold
              : AppColors.inkSoft,
        ),
        iconColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.gold
              : AppColors.inkSoft,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.white,
      selectedColor: AppColors.darkBackground,
      secondarySelectedColor: AppColors.darkBackground,
      checkmarkColor: AppColors.gold,
      labelStyle: TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
        color: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.gold
              : AppColors.ink,
        ),
      ),
      secondaryLabelStyle: const TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
        color: AppColors.gold,
      ),
      side: const BorderSide(color: AppColors.border),
      shape: _pillShape,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      hintStyle: const TextStyle(color: AppColors.gray),
      labelStyle: const TextStyle(color: AppColors.inkSoft),
      floatingLabelStyle: const TextStyle(
        color: AppColors.primary,
        fontWeight: FontWeight.w700,
      ),
      prefixIconColor: AppColors.gray,
      suffixIconColor: AppColors.gray,
      border: _inputBorder(AppColors.border),
      enabledBorder: _inputBorder(AppColors.border),
      disabledBorder: _inputBorder(AppColors.borderSoft),
      focusedBorder: _inputBorder(AppColors.primary, 1.8),
      errorBorder: _inputBorder(AppColors.primary),
      focusedErrorBorder: _inputBorder(AppColors.primary, 1.8),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 70,
      indicatorColor: AppColors.lightPink,
      indicatorShape: _pillShape,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 24,
          color: states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.gray,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        return TextStyle(
          color: states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.gray,
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w800
              : FontWeight.w600,
        );
      }),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: AppColors.gold,
      unselectedLabelColor: AppColors.inkSoft,
      labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
      unselectedLabelStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: Colors.transparent,
      indicator: BoxDecoration(
        color: AppColors.darkBackground,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      splashBorderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: AppColors.primary,
      titleTextStyle: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
      subtitleTextStyle: TextStyle(
        fontSize: 13,
        height: 1.35,
        color: AppColors.inkSoft,
      ),
    ),
    expansionTileTheme: const ExpansionTileThemeData(
      shape: Border(),
      collapsedShape: Border(),
      iconColor: AppColors.primary,
      collapsedIconColor: AppColors.gray,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shadowColor: AppColors.shadow.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      titleTextStyle: _textTheme.titleLarge,
      contentTextStyle: _textTheme.bodyMedium?.copyWith(
        color: AppColors.inkSoft,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.white,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: AppColors.border,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.charcoal,
      contentTextStyle: const TextStyle(
        color: AppColors.white,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      actionTextColor: AppColors.gold,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primary,
      linearTrackColor: AppColors.creamSecondary,
      circularTrackColor: Colors.transparent,
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.primary
            : AppColors.gray,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.white
            : AppColors.gray,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.primary
            : AppColors.creamSecondary,
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.borderSoft,
      thickness: 1,
      space: 1,
    ),
    dividerColor: AppColors.borderSoft,
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.charcoal,
        borderRadius: BorderRadius.circular(10),
      ),
      textStyle: const TextStyle(color: AppColors.white, fontSize: 12.5),
    ),
  );
}
