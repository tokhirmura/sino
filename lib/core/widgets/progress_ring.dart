import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Animated circular progress (0..1) with optional center child.
///
/// Design 2.0: the arc is a soft gradient of [color] (or [gradientColors])
/// with rounded caps.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    this.size = 120,
    this.strokeWidth = 12,
    this.color = AppColors.primary,
    this.trackColor,
    this.duration = const Duration(milliseconds: 800),
    this.child,
    this.semanticsLabel,
    this.gradientColors,
  });

  final double value;
  final double size;
  final double strokeWidth;
  final Color color;
  final Color? trackColor;
  final Duration duration;
  final Widget? child;

  /// Screen-reader label, e.g. «Suv: 6/8».
  final String? semanticsLabel;

  /// Arc colors from start to end, e.g. `[AppColors.primary,
  /// AppColors.secondary]`. Default: a lighter shade of [color] → [color].
  final List<Color>? gradientColors;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final track = trackColor ?? color.withValues(alpha: isDark ? 0.20 : 0.13);
    final target = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    final colors =
        gradientColors ?? [Color.lerp(color, Colors.white, 0.35)!, color];
    // Starts from 0 on first build; later value changes animate from the
    // current position (TweenAnimationBuilder keeps it).
    return Semantics(
      label: semanticsLabel,
      value: '${(target * 100).round()}%',
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: target),
        duration: duration,
        curve: Curves.easeOutCubic,
        builder: (context, v, child) => SizedBox.square(
          dimension: size,
          child: CustomPaint(
            painter: _RingPainter(
              value: v,
              colors: colors,
              track: track,
              stroke: strokeWidth,
            ),
            child: Center(child: child),
          ),
        ),
        child: child,
      ),
    );
  }
}

/// Hero progress ring: brand gradient (turquoise → lapis) and an animated
/// big number in the middle (percent by default).
///
/// ```dart
/// AnimatedProgressRing(value: 0.72, label: '1 520', caption: 'kkal')
/// ```
class AnimatedProgressRing extends StatelessWidget {
  const AnimatedProgressRing({
    super.key,
    required this.value,
    this.size = 140,
    this.strokeWidth = 14,
    this.label,
    this.caption,
    this.colors = const [AppColors.primary, AppColors.secondary],
    this.semanticsLabel,
    this.duration = const Duration(milliseconds: 1100),
  });

  final double value;
  final double size;
  final double strokeWidth;

  /// Center text; default — animated percent.
  final String? label;

  /// Small text under [label].
  final String? caption;
  final List<Color> colors;
  final String? semanticsLabel;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final target = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    final big = text.headlineMedium?.copyWith(fontSize: size * 0.2);
    return ProgressRing(
      value: target,
      size: size,
      strokeWidth: strokeWidth,
      color: colors.last,
      gradientColors: colors,
      duration: duration,
      semanticsLabel: semanticsLabel,
      child: Padding(
        padding: EdgeInsets.all(strokeWidth + 4),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (label != null)
                Text(label!, style: big)
              else
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: target),
                  duration: duration,
                  curve: Curves.easeOutCubic,
                  builder: (_, v, _) =>
                      Text('${(v * 100).round()}%', style: big),
                ),
              if (caption != null) Text(caption!, style: text.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.value,
    required this.colors,
    required this.track,
    required this.stroke,
  });

  final double value;
  final List<Color> colors;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arcRect, 0, math.pi * 2, false, base..color = track);
    if (value <= 0) return;
    final sweep = math.pi * 2 * value;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    if (colors.length < 2) {
      paint.color = colors.isEmpty ? track : colors.first;
    } else {
      paint.shader = SweepGradient(
        colors: colors,
        endAngle: math.max(sweep, 0.01),
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(arcRect);
    }
    canvas.drawArc(arcRect, -math.pi / 2, sweep, false, paint);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value ||
      !_sameColors(old.colors, colors) ||
      old.track != track ||
      old.stroke != stroke;

  static bool _sameColors(List<Color> a, List<Color> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
