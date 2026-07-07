import 'package:flutter/material.dart';

/// Bespoke, self-contained design tokens for the **auth flow only** (light
/// mode). Deliberately independent of the app's global `app_theme.dart` — a
/// from-scratch cinematic / frosted-glass identity for login → loading → home.
/// Dark mode is intentionally deferred.
class AuthColors {
  AuthColors._();

  // Living gradient — a soft warm-linen shimmer echoing the app's classic BENTO
  // canvas. We lerp between these two stop-sets on a slow loop; red lives only
  // on the accents (CTA, links, play button), exactly as in the classic theme.
  static const gradientA = <Color>[
    Color(0xFFFAF6EF), // warm white
    Color(0xFFF1EADD), // linen
    Color(0xFFE7DCC8), // warm sand
    Color(0xFFEFE8DA), // pale linen
  ];
  static const gradientB = <Color>[
    Color(0xFFF6F0E5), // cream
    Color(0xFFECE2D2), // warm linen
    Color(0xFFE0D3BD), // deeper sand
    Color(0xFFE9E1D2), // linen
  ];

  // Ink / text — aligned to the app's classic BENTO light palette (warm ink).
  static const ink = Color(0xFF1B1714); // primary text + wordmark
  static const inkSecondary = Color(0xFF5C554C);
  static const inkMuted = Color(0xFF8A8278);
  static const onInk = Color(0xFFFFFFFF);

  // Glass surfaces — frosted white panels over the warm linen, mirroring the
  // classic theme's white cards on a linen canvas.
  static const glassFill = Color(0xA6FFFFFF); // white ~65%
  static const glassBorder = Color(0x99FFFFFF); // white ~60%
  static const glassFieldFill = Color(0x80FFFFFF); // input fill ~50%
  static const fieldBorder = Color(0x261B1714); // warm ink ~15%
  static const hairline = Color(0x261B1714);

  // Accent — the app's brand ruby. Drives links, focus rings, the primary CTA,
  // and the demo-video play button (matches the classic theme's ruby accent).
  static const accent = Color(0xFFE8112D); // ruby red (brand)

  static const shadow = Color(0x1F1B1714); // soft, warm, premium
}

class AuthType {
  AuthType._();
  static const wordmark = TextStyle(
    fontFamily: 'SpaceGrotesk',
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.8,
    height: 1.0,
    color: AuthColors.ink,
  );
  static const eyebrow = TextStyle(
    fontFamily: 'SpaceGrotesk',
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 2.2,
    color: AuthColors.inkSecondary,
  );
  static const headline = TextStyle(
    fontFamily: 'SpaceGrotesk',
    fontSize: 34,
    fontWeight: FontWeight.w600,
    letterSpacing: -1.0,
    height: 1.05,
    color: AuthColors.ink,
  );
  static const title = TextStyle(
    fontFamily: 'SpaceGrotesk',
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
    color: AuthColors.ink,
  );
  static const body = TextStyle(
    fontFamily: 'Inter',
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.35,
    color: AuthColors.ink,
  );
  static const label = TextStyle(
    fontFamily: 'Inter',
    fontSize: 12.5,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
    color: AuthColors.inkSecondary,
  );
  static const button = TextStyle(
    fontFamily: 'Inter',
    fontSize: 15.5,
    fontWeight: FontWeight.w600,
    color: AuthColors.onInk,
  );
  static const link = TextStyle(
    fontFamily: 'Inter',
    fontSize: 13.5,
    fontWeight: FontWeight.w600,
    color: AuthColors.accent,
  );
}

class AuthSpace {
  AuthSpace._();
  static const gutter = 24.0;
  static const cardRadius = 30.0;
  static const fieldRadius = 16.0;
  static const buttonRadius = 16.0;
}

class AuthMotion {
  AuthMotion._();
  static const gradient = Duration(seconds: 12);
  static const headlineInterval = Duration(milliseconds: 3200);
  static const headlineSwitch = Duration(milliseconds: 450);
  static const entrance = Duration(milliseconds: 700);
  static const press = Duration(milliseconds: 110);
}
