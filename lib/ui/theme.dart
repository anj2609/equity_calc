import 'package:flutter/material.dart';

const _navy = Color(0xFF1F3864);

/// Colours not covered by the Material colour scheme.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.gain,
    required this.loss,
    required this.warn,
    required this.inputFill,
    required this.overrideFill,
    required this.overrideDot,
    required this.headerBg,
    required this.shadedRow,
  });

  final Color gain;
  final Color loss;
  final Color warn;

  /// Pale yellow like the spreadsheet's input cells.
  final Color inputFill;

  /// Stronger yellow for values overridden in one scenario.
  final Color overrideFill;
  final Color overrideDot;
  final Color headerBg;
  final Color shadedRow;

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>()!;

  /// Green for gains, red for losses, null (default text colour) for zero.
  Color? signed(double v) => v < -0.00004 ? loss : (v > 0.00004 ? gain : null);

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(AppColors? other, double t) =>
      t < 0.5 || other == null ? this : other;
}

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: _navy,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  );
  final barBg = dark ? scheme.surfaceContainerLow : _navy;
  final barFg = dark ? scheme.onSurface : Colors.white;
  final radius = BorderRadius.circular(18);
  final base = ThemeData(colorScheme: scheme, brightness: brightness);
  final text = base.textTheme.copyWith(
    headlineMedium: base.textTheme.headlineMedium?.copyWith(
      letterSpacing: -0.5,
    ),
    headlineSmall: base.textTheme.headlineSmall?.copyWith(letterSpacing: -0.3),
    titleSmall: base.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
    ),
    labelSmall: base.textTheme.labelSmall?.copyWith(letterSpacing: 0.2),
  );
  return base.copyWith(
    textTheme: text,
    scaffoldBackgroundColor: dark ? scheme.surface : const Color(0xFFF3F5FA),
    appBarTheme: AppBarTheme(
      backgroundColor: barBg,
      foregroundColor: barFg,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: text.titleLarge?.copyWith(
        color: barFg,
        fontWeight: FontWeight.w700,
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: barFg,
      unselectedLabelColor: barFg.withValues(alpha: 0.65),
      indicatorColor: dark ? scheme.primary : Colors.white,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: Colors.transparent,
      labelStyle: const TextStyle(fontWeight: FontWeight.w700),
    ),
    cardTheme: CardThemeData(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: dark ? scheme.surfaceContainer : Colors.white,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: dark ? 0.5 : 0.6),
        ),
        borderRadius: radius,
      ),
    ),
    chipTheme: base.chipTheme.copyWith(shape: const StadiumBorder()),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.8),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
    extensions: [
      AppColors(
        gain: dark ? const Color(0xFF4ADE80) : const Color(0xFF15803D),
        loss: dark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
        warn: dark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
        inputFill: dark ? const Color(0xFF26251D) : const Color(0xFFFFFBEB),
        overrideFill: dark ? const Color(0xFF4D4012) : const Color(0xFFFDE68A),
        overrideDot: dark ? const Color(0xFFFFD54F) : const Color(0xFFD97706),
        headerBg: dark ? const Color(0xFF24414F) : const Color(0xFF2F5D6E),
        shadedRow: dark ? const Color(0x14FFFFFF) : const Color(0xFFF1F4FA),
      ),
    ],
  );
}
