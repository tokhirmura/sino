import 'package:flutter/material.dart';

/// Design 2.0 «Samarqand» palette.
///
/// Brand: turquoise of the Registan domes → deep lapis. Saffron for
/// accents and rewards, pomegranate ([danger]) only for alarms and errors.
///
/// The old names ([sky], [violet], [amber], [coral], [good]) are kept so
/// existing screens pick up the new palette without code changes.
abstract final class AppColors {
  // ── Brand ────────────────────────────────────────────────────────────
  /// Registan turquoise — brand color for fills, rings, icons, gradients.
  static const primary = Color(0xFF0FB5AE);

  /// Deeper turquoise for text, links and solid buttons on light
  /// backgrounds (white text on it passes WCAG AA).
  static const primaryDeep = Color(0xFF08807B);

  /// Deep lapis — secondary brand color.
  static const secondary = Color(0xFF1D4ED8);

  /// Saffron — accents, highlights, rewards, achievements.
  static const saffron = Color(0xFFF5A524);

  /// Pomegranate — only alarms and errors.
  static const garnet = Color(0xFFE11D48);

  // ── Named accents (kept for existing screens) ────────────────────────
  static const turquoise = primary;
  static const lapis = secondary;
  static const sky = Color(0xFF2563EB);
  static const violet = Color(0xFF7C5CE6);
  static const amber = saffron;

  /// Warm terracotta of Samarkand brick (not an error color).
  static const coral = Color(0xFFEA7A5A);
  static const danger = garnet;
  static const good = Color(0xFF16A34A);

  // ── Surfaces ─────────────────────────────────────────────────────────
  /// Cream background (light theme).
  static const background = Color(0xFFFAF7F2);

  /// Night background (dark theme).
  static const backgroundDark = Color(0xFF0B1220);
  static const surfaceDark = Color(0xFF131B2C);

  /// Main text color in the light theme (deep navy, not pure black).
  static const ink = Color(0xFF14202B);

  // ── Shape ────────────────────────────────────────────────────────────
  static const cardRadius = 24.0;

  // ── Gradients ────────────────────────────────────────────────────────
  /// Turquoise → lapis: headers, primary buttons, hero rings.
  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, secondary],
  );

  /// Slightly deeper brand gradient for the dark theme.
  static const brandGradientDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0C9C96), Color(0xFF1E3FAE)],
  );

  /// Saffron gradient for rewards and achievements.
  static const saffronGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFC85C), saffron, Color(0xFFE0861A)],
  );

  /// Brand gradient for the given theme brightness.
  static LinearGradient brand(Brightness brightness) =>
      brightness == Brightness.dark ? brandGradientDark : brandGradient;

  /// [color] adjusted to stay readable as text / icon on the theme's
  /// surfaces (contrast ≥ 4.5, WCAG AA): darker on light backgrounds,
  /// lighter on dark ones. Hue is kept.
  static Color readable(Color color, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final bg = dark ? surfaceDark : Colors.white;
    final bgL = bg.computeLuminance();
    double contrast(Color c) {
      final l = c.computeLuminance();
      return l > bgL ? (l + 0.05) / (bgL + 0.05) : (bgL + 0.05) / (l + 0.05);
    }

    var hsl = HSLColor.fromColor(color);
    for (var i = 0; i < 50 && contrast(hsl.toColor()) < 4.5; i++) {
      final next = (hsl.lightness + (dark ? 0.02 : -0.02)).clamp(0.0, 1.0);
      if (next == hsl.lightness) break;
      hsl = hsl.withLightness(next);
    }
    return hsl.toColor();
  }
}
