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
  static const cardGap = sm;
}

/// Soft card shadows. Dark theme relies on a hairline border instead,
/// so its shadow is subtle.
abstract final class AppShadows {
  static const _light = [
    BoxShadow(
      color: Color(0x140F2A27),
      blurRadius: 24,
      spreadRadius: -6,
      offset: Offset(0, 10),
    ),
    BoxShadow(color: Color(0x0A0F2A27), blurRadius: 4, offset: Offset(0, 1)),
  ];

  static const _dark = [
    BoxShadow(color: Color(0x40000000), blurRadius: 16, offset: Offset(0, 6)),
  ];

  static List<BoxShadow> soft(Brightness brightness) =>
      brightness == Brightness.dark ? _dark : _light;
}
