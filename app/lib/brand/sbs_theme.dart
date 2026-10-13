
import 'package:flutter/material.dart';

import 'sbs_colors.dart';

/// Schriftfamilie (self-hosted, siehe pubspec.yaml).
const String kSbsFont = 'Saira';

const List<FontFeature> kTabular = [FontFeature.tabularFigures()];

/// Text-Stile des Design-Systems.
class SbsText {
  SbsText._();

  /// Display/Überschrift: 800 kursiv, Großbuchstaben (Text selbst in
  /// Großbuchstaben setzen, z. B. via `.toUpperCase()`).
  static TextStyle display(double size, {Color color = SbsColors.fg}) =>
      TextStyle(
        fontFamily: kSbsFont,
        fontWeight: FontWeight.w800,
        fontStyle: FontStyle.italic,
        fontSize: size,
        letterSpacing: size * 0.02,
        height: 1.05,
        color: color,
      );

  /// Kennzahlen / Uhrzeiten / Codes: 700 kursiv, tabellarische Ziffern.
  static TextStyle number(double size, {Color color = SbsColors.fg}) =>
      TextStyle(
        fontFamily: kSbsFont,
        fontWeight: FontWeight.w700,
        fontStyle: FontStyle.italic,
        fontSize: size,
        height: 1.05,
        fontFeatures: kTabular,
        color: color,
      );

  /// Label: 600, GROSSBUCHSTABEN (Text selbst), 11–12 px, +0,12 em.
  static TextStyle label({Color color = SbsColors.fgMuted, double size = 11.5}) =>
      TextStyle(
        fontFamily: kSbsFont,
        fontWeight: FontWeight.w600,
        fontSize: size,
        letterSpacing: size * 0.12,
        color: color,
      );

  static TextStyle body(
          {double size = 15,
          Color color = SbsColors.fg,
          FontWeight weight = FontWeight.w400}) =>
      TextStyle(
        fontFamily: kSbsFont,
        fontWeight: weight,
        fontSize: size,
        height: 1.35,
        color: color,
      );
}

ThemeData buildSbsTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: SbsColors.fg,
    onPrimary: SbsColors.onFg,
    secondary: SbsColors.fg,
    onSecondary: SbsColors.onFg,
    error: SbsColors.signal,
    onError: SbsColors.onFg,
    surface: SbsColors.surface,
    onSurface: SbsColors.fg,
    onSurfaceVariant: SbsColors.fgMuted,
    outline: SbsColors.lineStrong,
    outlineVariant: SbsColors.line,
    surfaceContainerLowest: SbsColors.bg,
    surfaceContainerLow: SbsColors.surface,
    surfaceContainer: SbsColors.surface,
    surfaceContainerHigh: SbsColors.surface2,
    surfaceContainerHighest: SbsColors.surface2,
    inverseSurface: SbsColors.fg,
    onInverseSurface: SbsColors.onFg,
    surfaceTint: Colors.transparent,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    fontFamily: kSbsFont,
    scaffoldBackgroundColor: SbsColors.bg,
    canvasColor: SbsColors.bg,
    splashFactory: InkRipple.splashFactory,
    dividerColor: SbsColors.line,
  );

  final textTheme = base.textTheme
      .apply(
        fontFamily: kSbsFont,
        bodyColor: SbsColors.fg,
        displayColor: SbsColors.fg,
      )
      .copyWith(
        displayLarge: SbsText.display(44),
        displayMedium: SbsText.display(36),
        displaySmall: SbsText.display(30),
        headlineLarge: SbsText.display(28),
        headlineMedium: SbsText.display(24),
        headlineSmall: SbsText.display(20),
        titleLarge: SbsText.display(18),
        titleMedium: SbsText.body(size: 16, weight: FontWeight.w600),
        titleSmall: SbsText.body(size: 14, weight: FontWeight.w600),
        bodyLarge: SbsText.body(size: 16),
        bodyMedium: SbsText.body(size: 14.5),
        bodySmall: SbsText.body(size: 12.5, color: SbsColors.fgMuted),
        labelLarge: SbsText.body(size: 15, weight: FontWeight.w700),
        labelMedium: SbsText.label(),
        labelSmall: SbsText.label(size: 10.5),
      );

  const smallRadius = BorderRadius.all(Radius.circular(4));
  const cardRadius = BorderRadius.all(Radius.circular(10));

  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: smallRadius,
        borderSide: BorderSide(color: c, width: w),
      );

  final buttonText = SbsText.body(size: 16, weight: FontWeight.w700)
      .copyWith(letterSpacing: 0.4);

  return base.copyWith(
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: SbsColors.bg,
      foregroundColor: SbsColors.fg,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: SbsText.display(20),
    ),
    cardTheme: const CardThemeData(
      color: SbsColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: cardRadius,
        side: BorderSide(color: SbsColors.line),
      ),
    ),
    dividerTheme: const DividerThemeData(color: SbsColors.line, space: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: SbsColors.fg,
        foregroundColor: SbsColors.onFg,
        disabledBackgroundColor: SbsColors.surface2,
        disabledForegroundColor: SbsColors.fgFaint,
        minimumSize: const Size(64, 52),
        shape: const RoundedRectangleBorder(borderRadius: smallRadius),
        textStyle: buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: SbsColors.fg,
        disabledForegroundColor: SbsColors.fgFaint,
        minimumSize: const Size(64, 48),
        side: const BorderSide(color: SbsColors.lineStrong),
        shape: const RoundedRectangleBorder(borderRadius: smallRadius),
        textStyle: buttonText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: SbsColors.fg,
        shape: const RoundedRectangleBorder(borderRadius: smallRadius),
        textStyle: buttonText.copyWith(fontSize: 15),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: SbsColors.surface2,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: SbsText.body(color: SbsColors.fgFaint),
      labelStyle: SbsText.label(),
      floatingLabelStyle: SbsText.label(color: SbsColors.fg),
      errorStyle: SbsText.body(size: 12.5, color: SbsColors.signal),
      border: border(SbsColors.line),
      enabledBorder: border(SbsColors.line),
      focusedBorder: border(SbsColors.fg),
      errorBorder: border(SbsColors.signal),
      focusedErrorBorder: border(SbsColors.signal, 1.5),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: SbsColors.fg,
      selectionColor: Color(0x55EEEDE6),
      selectionHandleColor: SbsColors.fg,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: SbsColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 64,
      indicatorColor: SbsColors.surface2,
      indicatorShape: const RoundedRectangleBorder(borderRadius: smallRadius),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
            size: 24,
            color: s.contains(WidgetState.selected)
                ? SbsColors.fg
                : SbsColors.fgMuted,
          )),
      labelTextStyle: WidgetStateProperty.resolveWith((s) => SbsText.label(
            size: 10.5,
            color: s.contains(WidgetState.selected)
                ? SbsColors.fg
                : SbsColors.fgMuted,
          )),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: SbsColors.surface2,
      contentTextStyle: SbsText.body(),
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(
        borderRadius: smallRadius,
        side: BorderSide(color: SbsColors.lineStrong),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: SbsColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: cardRadius,
        side: BorderSide(color: SbsColors.lineStrong),
      ),
      titleTextStyle: SbsText.display(20),
      contentTextStyle: SbsText.body(color: SbsColors.fgMuted),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: SbsColors.surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: SbsColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
        side: BorderSide(color: SbsColors.lineStrong),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: SbsColors.fg,
      linearTrackColor: SbsColors.line,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: SbsColors.fg,
      textColor: SbsColors.fg,
    ),
  );
}
