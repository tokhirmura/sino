import 'package:flutter/material.dart';

/// Spacing scale (4-pt grid). Prefer these over magic numbers.
abstract final class AppSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  /// Horizontal padding of every screen (matches [AppScaffold]).
  static const screen = EdgeInsets.symmetric(horizontal: md);

  /// Gap between cards in a list.
  static const cardGap = 14.0;
}

/// Corner radii of design 2.0.
abstract final class AppRadius {
  static const card = 24.0;
  static const button = 18.0;
  static const input = 16.0;
  static const chip = 999.0;
  static const sheet = 32.0;
}

/// Motion tokens: one place to tune the feel of the whole app.
abstract final class AppMotion {
  static const fast = Duration(milliseconds: 140);
  static const medium = Duration(milliseconds: 320);
  static const slow = Duration(milliseconds: 600);

  /// Delay between cards appearing one after another (cascade).
  static const stagger = Duration(milliseconds: 55);

  static const enter = Curves.easeOutCubic;

  /// Springy release after a press.
  static const spring = Curves.elasticOut;
}

/// Soft card shadows. Dark theme relies on a hairline border instead,
/// so its shadow is subtle.
abstract final class AppShadows {
  static const _light = [
    BoxShadow(
      color: Color(0x121B2A4A),
      blurRadius: 32,
      spreadRadius: -8,
      offset: Offset(0, 14),
    ),
    BoxShadow(color: Color(0x0A1B2A4A), blurRadius: 6, offset: Offset(0, 2)),
  ];

  static const _dark = [
    BoxShadow(color: Color(0x59000000), blurRadius: 24, offset: Offset(0, 10)),
  ];

  static List<BoxShadow> soft(Brightness brightness) =>
      brightness == Brightness.dark ? _dark : _light;

  /// Colored glow under gradient buttons and hero elements.
  static List<BoxShadow> glow(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.32),
      blurRadius: 22,
      spreadRadius: -6,
      offset: const Offset(0, 10),
    ),
  ];
}
