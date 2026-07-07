import 'package:flutter/material.dart';

import '../../shared/models/models.dart';

/// Single source of truth for every colour in the app.
/// `dark` and `light` are both registered as a [ThemeExtension] on their
/// respective [ThemeData], and widgets read them via `context.c.<token>`.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color border;
  final Color borderStrong;
  final Color accent;
  final Color accentDim;
  final Color accentSoft;
  final Color onAccent; // contrast text on a filled accent button
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color textDim;
  final Color positive;
  final Color negative;
  final Color amber;
  final Color athletic;
  final Color mind;
  final Color body;
  final Color indigo;

  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.border,
    required this.borderStrong,
    required this.accent,
    required this.accentDim,
    required this.accentSoft,
    required this.onAccent,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textDim,
    required this.positive,
    required this.negative,
    required this.amber,
    required this.athletic,
    required this.mind,
    required this.body,
    required this.indigo,
  });

  /// OBSIDIAN — ultra-premium true-black dark mode. No blue cast: a pure-black
  /// OLED canvas, warm-neutral charcoal surfaces stepped by tone, lifted with
  /// light hairlines (drop shadows read as nothing on black), crisp warm-white
  /// ink, and a single restrained ruby accent. Minimal, high-contrast, and
  /// expensive-feeling — the old blue-grey "Void Fire" set is retired.
  static const dark = AppPalette(
    background:      Color(0xFF000000), // true black (OLED)
    surface:         Color(0xFF161513), // warm-charcoal card, lifted off black
    surfaceElevated: Color(0xFF222120), // raised fill: inputs, tracks, chips
    border:          Color(0x14FFFFFF), // white @ ~8% — crisp hairline edge
    borderStrong:    Color(0x29FFFFFF), // white @ ~16%
    accent:          Color(0xFFF0233A), // refined ruby, tuned to sit on black
    accentDim:       Color(0xFFB50022),
    accentSoft:      Color(0x29F0233A), // ~16% red wash — used sparingly
    onAccent:        Color(0xFFFFFFFF),
    textPrimary:     Color(0xFFF5F4F2), // warm near-white
    textSecondary:   Color(0xFFA8A6A1), // warm grey
    textMuted:       Color(0xFF787671),
    textDim:         Color(0xFF4A4946),
    positive:        Color(0xFF30D158),
    negative:        Color(0xFFFF453A),
    amber:           Color(0xFFF2B544),
    athletic:        Color(0xFFE0743C), // warm orange
    mind:            Color(0xFF4C9BE0), // steel blue (data accent only)
    body:            Color(0xFFA77BD4), // muted violet
    indigo:          Color(0xFF6E5BE0),
  );

  /// BENTO — warm linen canvas, ruby red accent. Design default.
  static const light = AppPalette(
    background:      Color(0xFFEDE9E2), // warm linen
    surface:         Color(0xFFFFFFFF), // pure white card
    surfaceElevated: Color(0xFFF2ECE3), // recessed fills / inset — separates from white
    border:          Color(0x1A1B1714), // rgba(27,23,20,.10) — crisper card edges
    borderStrong:    Color(0x2E1B1714), // rgba(27,23,20,.18)
    accent:          Color(0xFFE8112D), // ruby red
    accentDim:       Color(0xFFB50022),
    accentSoft:      Color(0x17E8112D), // rgba(232,17,45,.09)
    onAccent:        Color(0xFFFFFFFF),
    textPrimary:     Color(0xFF1B1714), // deep ink
    textSecondary:   Color(0xFF5C554C), // a touch darker for body legibility
    textMuted:       Color(0xFF8A8278), // darker than before — readable on linen
    textDim:         Color(0xFFAEA597),
    positive:        Color(0xFF3F7E55),
    negative:        Color(0xFFE8112D),
    amber:           Color(0xFFD2912E),
    athletic:        Color(0xFFD2622E), // orange-rust
    mind:            Color(0xFF3D6D94), // mind = blue
    body:            Color(0xFF7E5A8E), // body = purple
    indigo:          Color(0xFF4F46E5),
  );

  @override
  AppPalette copyWith({
    Color? background, Color? surface, Color? surfaceElevated,
    Color? border, Color? borderStrong,
    Color? accent, Color? accentDim, Color? accentSoft, Color? onAccent,
    Color? textPrimary, Color? textSecondary, Color? textMuted, Color? textDim,
    Color? positive, Color? negative, Color? amber,
    Color? athletic, Color? mind, Color? body,
    Color? indigo,
  }) {
    return AppPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      accent: accent ?? this.accent,
      accentDim: accentDim ?? this.accentDim,
      accentSoft: accentSoft ?? this.accentSoft,
      onAccent: onAccent ?? this.onAccent,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      textDim: textDim ?? this.textDim,
      positive: positive ?? this.positive,
      negative: negative ?? this.negative,
      amber: amber ?? this.amber,
      athletic: athletic ?? this.athletic,
      mind: mind ?? this.mind,
      body: body ?? this.body,
      indigo: indigo ?? this.indigo,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentDim: Color.lerp(accentDim, other.accentDim, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textDim: Color.lerp(textDim, other.textDim, t)!,
      positive: Color.lerp(positive, other.positive, t)!,
      negative: Color.lerp(negative, other.negative, t)!,
      amber: Color.lerp(amber, other.amber, t)!,
      athletic: Color.lerp(athletic, other.athletic, t)!,
      mind: Color.lerp(mind, other.mind, t)!,
      body: Color.lerp(body, other.body, t)!,
      indigo: Color.lerp(indigo, other.indigo, t)!,
    );
  }
}

/// `context.c.background`, `context.c.accent`, …
extension AppPaletteCtx on BuildContext {
  AppPalette get c => Theme.of(this).extension<AppPalette>()!;
  AppTextStyles get t => AppTextStyles._(c);
}

/// Section → palette colour. Single source of truth for the athletic / mind /
/// body accent that was previously copy-pasted as a `switch` into ~8 screens.
extension HabitSectionColor on HabitSection {
  Color color(AppPalette c) => switch (this) {
        HabitSection.athletic => c.athletic,
        HabitSection.mind => c.mind,
        HabitSection.body => c.body,
      };
}

/// Base type tokens — font, size, weight, tracking. No colour.
/// Use via `context.t.<style>` which applies the theme's text colour.
class AppType {
  static const TextStyle display = TextStyle(
    fontFamily: 'SpaceGrotesk',
    fontSize: 56,
    fontWeight: FontWeight.w700,
    height: 0.95,
    letterSpacing: -2.5,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const TextStyle h1 = TextStyle(
    fontFamily: 'SpaceGrotesk',
    fontSize: 26,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.6,
    height: 1.15,
  );
  static const TextStyle h2 = TextStyle(
    fontFamily: 'SpaceGrotesk',
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
  );
  static const TextStyle numLg = TextStyle(
    fontFamily: 'SpaceGrotesk',
    fontSize: 20,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
    height: 1.0,
  );
  static const TextStyle numMd = TextStyle(
    fontFamily: 'SpaceGrotesk',
    fontSize: 15,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const TextStyle body = TextStyle(
    fontFamily: 'Inter',
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.35,
  );
  static const TextStyle bodyStrong = TextStyle(
    fontFamily: 'Inter',
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );
  static const TextStyle label = TextStyle(
    fontFamily: 'Inter',
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.2,
  );
  static const TextStyle meta = TextStyle(
    fontFamily: 'Inter',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.2,
  );
  static const TextStyle overline = TextStyle(
    fontFamily: 'SpaceGrotesk',
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
  );
}

/// Pre-coloured text styles for the current theme.
class AppTextStyles {
  final AppPalette _c;
  AppTextStyles._(this._c);
  TextStyle get display    => AppType.display.copyWith(color: _c.textPrimary);
  TextStyle get h1         => AppType.h1.copyWith(color: _c.textPrimary);
  TextStyle get h2         => AppType.h2.copyWith(color: _c.textPrimary);
  TextStyle get numLg      => AppType.numLg.copyWith(color: _c.textPrimary);
  TextStyle get numMd      => AppType.numMd.copyWith(color: _c.textPrimary);
  TextStyle get body       => AppType.body.copyWith(color: _c.textPrimary);
  TextStyle get bodyStrong => AppType.bodyStrong.copyWith(color: _c.textPrimary);
  TextStyle get label      => AppType.label.copyWith(color: _c.textMuted);
  TextStyle get meta       => AppType.meta.copyWith(color: _c.textDim);
  TextStyle get overline   => AppType.overline.copyWith(color: _c.textMuted);
}

/// Shape tokens — BENTO theme.
class AppRadii {
  static const card   = 18.0;
  static const chip   = 13.0;
  static const button = 13.0;
  static const lg     = 22.0;
  static const xl     = 26.0;
  static const pill   = 99.0;
}

class AppSpace {
  static const screenH = 20.0;
}

/// Elevation tokens — one soft, warm-neutral shadow scale so every surface
/// lifts consistently instead of each screen inventing its own (and the stray
/// `Colors.black54` sheet shadows). Tuned for light mode; quietly subtle on dark.
class AppShadows {
  /// Resting card / tile.
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x0D000000), // black @ 5%
      blurRadius: 9,
      offset: Offset(0, 2),
    ),
  ];

  /// A lifted / active surface (focused card, FAB, pressed-into-front).
  static const List<BoxShadow> elevated = [
    BoxShadow(
      color: Color(0x14000000), // black @ 8%
      blurRadius: 18,
      spreadRadius: -2,
      offset: Offset(0, 8),
    ),
    BoxShadow(
      color: Color(0x0D000000),
      blurRadius: 9,
      offset: Offset(0, 2),
    ),
  ];

  /// Bottom sheet / overlay rising above the scrim.
  static const List<BoxShadow> sheet = [
    BoxShadow(
      color: Color(0x24000000), // black @ 14%
      blurRadius: 30,
      spreadRadius: -4,
      offset: Offset(0, -6),
    ),
  ];
}

/// Theme factory.
class AppTheme {
  static ThemeData dark()  => _build(AppPalette.dark,  Brightness.dark);
  static ThemeData light() => _build(AppPalette.light, Brightness.light);

  static ThemeData _build(AppPalette p, Brightness b) {
    return ThemeData(
      useMaterial3: true,
      brightness: b,
      scaffoldBackgroundColor: p.background,
      canvasColor: p.background,
      fontFamily: 'Inter',
      extensions: [p],
      colorScheme: ColorScheme(
        brightness: b,
        primary: p.accent,
        onPrimary: p.onAccent,
        secondary: p.accent,
        onSecondary: p.onAccent,
        surface: p.surface,
        onSurface: p.textPrimary,
        error: p.negative,
        onError: p.onAccent,
      ),
      textTheme: TextTheme(
        displayLarge:   AppType.display.copyWith(color: p.textPrimary),
        headlineMedium: AppType.h1.copyWith(color: p.textPrimary),
        titleLarge:     AppType.h2.copyWith(color: p.textPrimary),
        bodyLarge:      AppType.body.copyWith(color: p.textPrimary),
        bodyMedium:     AppType.body.copyWith(color: p.textPrimary),
        labelLarge:     AppType.label.copyWith(color: p.textMuted),
        labelMedium:    AppType.label.copyWith(color: p.textMuted),
        labelSmall:     AppType.overline.copyWith(color: p.textMuted),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppType.h2.copyWith(color: p.textPrimary),
        iconTheme: IconThemeData(color: p.textPrimary, size: 22),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        // White fill + a defined border so inputs always read as inputs — on
        // the linen background the white pops; on white cards the border holds.
        fillColor: p.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.button),
          borderSide: BorderSide(color: p.borderStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.button),
          borderSide: BorderSide(color: p.borderStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.button),
          borderSide: BorderSide(color: p.accent, width: 1.5),
        ),
        hintStyle: TextStyle(
          color: p.textDim,
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: p.onAccent,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: p.onAccent,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.accent,
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      dividerColor: p.border,
      dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.surfaceElevated,
        contentTextStyle: AppType.bodyStrong.copyWith(color: p.textPrimary),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
