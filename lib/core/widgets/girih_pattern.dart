import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Thin geometric girih ornament (8-point khatam stars joined by a lattice,
/// small diamonds in between) — the tilework of Samarkand madrasahs.
///
/// Drawn with a [CustomPainter], no images. Meant as a 6–10 % overlay on
/// gradient headers: `Stack(children: [GirihPattern(), …])`.
class GirihPattern extends StatelessWidget {
  const GirihPattern({
    super.key,
    this.color = Colors.white,
    this.opacity = 0.08,
    this.cellSize = 46,
    this.strokeWidth = 1.1,
  });

  final Color color;

  /// 0.06–0.10 recommended.
  final double opacity;
  final double cellSize;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: GirihPainter(
            color: color.withValues(alpha: opacity),
            cellSize: cellSize,
            strokeWidth: strokeWidth,
          ),
        ),
      ),
    );
  }
}

class GirihPainter extends CustomPainter {
  GirihPainter({
    required this.color,
    this.cellSize = 46,
    this.strokeWidth = 1.1,
  });

  final Color color;
  final double cellSize;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.miter
      ..isAntiAlias = true;

    final s = cellSize;
    final r = s * 0.31; // star radius (tip)
    final d = s * 0.15; // diamond radius
    final path = Path();

    // One row/column beyond the edges so the pattern is seamless.
    final cols = (size.width / s).ceil() + 1;
    final rows = (size.height / s).ceil() + 1;
    for (var i = -1; i <= cols; i++) {
      for (var j = -1; j <= rows; j++) {
        final c = Offset(i * s, j * s);
        _star(path, c, r);
        // Lattice: star tip → neighbour's tip (right and down).
        path
          ..moveTo(c.dx + r, c.dy)
          ..lineTo(c.dx + s - r, c.dy)
          ..moveTo(c.dx, c.dy + r)
          ..lineTo(c.dx, c.dy + s - r);
        // Diamond in the middle of each cell, linked to the star corners.
        final m = c + Offset(s / 2, s / 2);
        path
          ..moveTo(m.dx, m.dy - d)
          ..lineTo(m.dx + d, m.dy)
          ..lineTo(m.dx, m.dy + d)
          ..lineTo(m.dx - d, m.dy)
          ..close();
        final k = r * math.cos(math.pi / 4);
        path
          ..moveTo(c.dx + k, c.dy + k)
          ..lineTo(m.dx - d * 0.7, m.dy - d * 0.7);
      }
    }
    canvas.drawPath(path, paint);
  }

  /// 8-point star = two overlapping squares (one turned by 45°).
  void _star(Path path, Offset c, double r) {
    for (final rot in const [0.0, math.pi / 4]) {
      for (var k = 0; k < 4; k++) {
        final a = rot + k * math.pi / 2;
        final p = c + Offset(math.cos(a) * r, math.sin(a) * r);
        k == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      path.close();
    }
    // Inner octagon.
    final ri = r * 0.42;
    for (var k = 0; k < 8; k++) {
      final a = math.pi / 8 + k * math.pi / 4;
      final p = c + Offset(math.cos(a) * ri, math.sin(a) * ri);
      k == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
  }

  @override
  bool shouldRepaint(GirihPainter old) =>
      old.color != color ||
      old.cellSize != cellSize ||
      old.strokeWidth != strokeWidth;
}
