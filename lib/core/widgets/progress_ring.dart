import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Animated circular progress (0..1) with optional center child.
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final track = trackColor ?? color.withValues(alpha: isDark ? 0.22 : 0.15);
    final target = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
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
              color: color,
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

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.value,
    required this.color,
    required this.track,
    required this.stroke,
  });

  final double value;
  final Color color;
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
    if (value > 0) {
      canvas.drawArc(
        arcRect,
        -math.pi / 2,
        math.pi * 2 * value,
        false,
        base..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value ||
      old.color != color ||
      old.track != track ||
      old.stroke != stroke;
}
