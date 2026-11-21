// Generates the Sino app icon and splash images (no dependencies).
//
//   dart run tool/core/gen_icon.dart
//
// Output (assets/branding/, not bundled into the app — only read by
// flutter_launcher_icons / flutter_native_splash):
//   icon.png             1024×1024 — gradient + girih + white dome
//   icon_foreground.png  1024×1024 — dome only, transparent (Android adaptive)
//   icon_background.png  1024×1024 — gradient + girih (Android adaptive)
//   splash_logo.png      1152×1152 — white dome, transparent (splash screen)
//
// Then: dart run flutter_launcher_icons && dart run flutter_native_splash:create
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const _turquoise = [0x0F, 0xB5, 0xAE];
const _lapis = [0x1D, 0x4E, 0xD8];

void main() {
  final out = Directory('assets/branding')..createSync(recursive: true);
  _write('${out.path}/icon.png', _render(1024, bg: true, dome: true));
  _write(
    '${out.path}/icon_foreground.png',
    // Android insets the adaptive foreground by 16 % and crops to ~66 % —
    // at scale 1.0 the dome ends up inside the safe zone.
    _render(1024, bg: false, dome: true, domeScale: 1.0),
  );
  _write('${out.path}/icon_background.png', _render(1024, bg: true));
  _write(
    '${out.path}/splash_logo.png',
    // Android 12 splash shows the icon inside a 768 px circle of 1152.
    _render(1152, bg: false, dome: true, domeScale: 0.5),
  );
  stdout.writeln('Wrote icons to ${out.path}/');
}

/// RGBA pixels of a [size]² image.
Uint8List _render(
  int size, {
  required bool bg,
  bool dome = false,
  double domeScale = 0.78,
}) {
  final px = Uint8List(size * size * 4);
  const ss = 4; // supersampling per axis for smooth edges
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      var r = 0.0, g = 0.0, b = 0.0, a = 0.0;
      for (var sy = 0; sy < ss; sy++) {
        for (var sx = 0; sx < ss; sx++) {
          final u = (x + (sx + 0.5) / ss) / size;
          final v = (y + (sy + 0.5) / ss) / size;
          var cr = 0.0, cg = 0.0, cb = 0.0, ca = 0.0;
          if (bg) {
            final t = ((u + v) / 2).clamp(0.0, 1.0);
            cr = _lerp(_turquoise[0], _lapis[0], t);
            cg = _lerp(_turquoise[1], _lapis[1], t);
            cb = _lerp(_turquoise[2], _lapis[2], t);
            // Soft light from the top-left.
            final glow = math.max(0, 1 - math.sqrt(u * u + v * v) / 0.9) * 0.18;
            cr += (255 - cr) * glow;
            cg += (255 - cg) * glow;
            cb += (255 - cb) * glow;
            if (_girih(u, v, 1 / 7)) {
              cr += (255 - cr) * 0.09;
              cg += (255 - cg) * 0.09;
              cb += (255 - cb) * 0.09;
            }
            ca = 255;
          }
          if (dome) {
            // Map into the dome's own unit square, centered.
            final du = (u - 0.5) / domeScale + 0.5;
            final dv = (v - 0.5) / domeScale + 0.5;
            final d = _domeCoverage(du, dv);
            if (d > 0) {
              // White dome; ribs are a touch tinted by the brand color.
              final rib = _rib(du, dv) ? 0.86 : 1.0;
              final wr = 255 * rib + _turquoise[0] * (1 - rib);
              final wg = 255 * rib + _turquoise[1] * (1 - rib);
              final wb = 255 * rib + _turquoise[2] * (1 - rib);
              cr = cr * (1 - d) + wr * d;
              cg = cg * (1 - d) + wg * d;
              cb = cb * (1 - d) + wb * d;
              ca = ca + (255 - ca) * d;
            }
          }
          r += cr * ca;
          g += cg * ca;
          b += cb * ca;
          a += ca;
        }
      }
      final i = (y * size + x) * 4;
      final n = ss * ss;
      if (a > 0) {
        px[i] = (r / a).round().clamp(0, 255);
        px[i + 1] = (g / a).round().clamp(0, 255);
        px[i + 2] = (b / a).round().clamp(0, 255);
      }
      px[i + 3] = (a / n).round().clamp(0, 255);
    }
  }
  return px;
}

double _lerp(int a, int b, double t) => a + (b - a) * t;

/// Thin 8-point-star lattice (same motif as the in-app GirihPattern).
bool _girih(double u, double v, double cell) {
  const w = 0.0035;
  final cx = (u / cell).roundToDouble() * cell;
  final cy = (v / cell).roundToDouble() * cell;
  final dx = u - cx, dy = v - cy;
  final r = cell * 0.31;
  // Two squares (axis-aligned diamond + rotated) → 8-point star outline.
  final diamond = (dx.abs() + dy.abs() - r).abs() < w;
  final k = r * math.cos(math.pi / 4);
  final square = (math.max(dx.abs(), dy.abs()) - k).abs() < w;
  // Lattice lines between stars.
  final lineH = dy.abs() < w && dx.abs() > r;
  final lineV = dx.abs() < w && dy.abs() > r;
  return diamond || square || lineH || lineV;
}

/// Half-width of the ribbed melon dome (Gur-e-Amir) at height [v], or
/// null outside it. Pointed top at 0.20, widest at 0.40, sits on the drum.
double? _domeHalfWidth(double v) {
  const tip = 0.20, mid = 0.40, wMax = 0.25, drum = 0.17;
  if (v < tip) return null;
  if (v <= mid) {
    return wMax *
        math.pow(math.sin(math.pi / 2 * (v - tip) / (mid - tip)), 0.7);
  }
  final k = (v - mid) / 0.17;
  if (k >= 1) return null;
  final w = wMax * math.sqrt(1 - k * k);
  return w < drum ? null : w;
}

/// 1 inside the dome silhouette, 0 outside (point sampling; the caller
/// supersamples).
double _domeCoverage(double u, double v) {
  final dx = (u - 0.5).abs();
  // Finial: thin spire with a small ball.
  if (dx < 0.008 && v > 0.13 && v < 0.215) return 1;
  final ball = math.sqrt(math.pow(u - 0.5, 2) + math.pow(v - 0.16, 2));
  if (ball < 0.019) return 1;

  final w = _domeHalfWidth(v);
  if (w != null && dx <= w) return 1;

  // Drum under the dome, with three arched windows.
  if (v > 0.50 && v < 0.70 && dx < 0.17) {
    for (final c in const [0.415, 0.5, 0.585]) {
      final inWin = (u - c).abs() < 0.024 && v > 0.60 && v < 0.67;
      final arch =
          math.sqrt(math.pow(u - c, 2) + math.pow(v - 0.60, 2)) < 0.024;
      if (inWin || arch) return 0;
    }
    return 1;
  }
  // Base slab with rounded ends.
  if (v >= 0.70 && v <= 0.76) {
    const half = 0.25, rr = 0.03;
    final ex = dx - (half - rr);
    if (ex <= 0) return 1;
    final ey = v - 0.73;
    return math.sqrt(ex * ex + ey * ey) <= rr ? 1 : 0;
  }
  return 0;
}

/// Curved ribs following the dome bulge (subtle).
bool _rib(double u, double v) {
  final w = _domeHalfWidth(v);
  if (w == null || v < 0.23) return false;
  for (final k in const [-0.66, -0.33, 0.0, 0.33, 0.66]) {
    if ((u - (0.5 + k * w)).abs() < 0.0045) return true;
  }
  return false;
}

// ── Minimal PNG encoder ────────────────────────────────────────────────

void _write(String path, Uint8List rgba) {
  final size = math.sqrt(rgba.length / 4).round();
  final raw = BytesBuilder();
  for (var y = 0; y < size; y++) {
    raw.addByte(0); // filter: none
    raw.add(Uint8List.sublistView(rgba, y * size * 4, (y + 1) * size * 4));
  }
  final ihdr = ByteData(13)
    ..setUint32(0, size)
    ..setUint32(4, size)
    ..setUint8(8, 8) // bit depth
    ..setUint8(9, 6) // RGBA
    ..setUint8(10, 0)
    ..setUint8(11, 0)
    ..setUint8(12, 0);
  final png = BytesBuilder()
    ..add(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
    ..add(_chunk('IHDR', ihdr.buffer.asUint8List()))
    ..add(_chunk('IDAT', ZLibEncoder(level: 9).convert(raw.takeBytes())))
    ..add(_chunk('IEND', const []));
  File(path).writeAsBytesSync(png.takeBytes());
}

List<int> _chunk(String type, List<int> data) {
  final t = type.codeUnits;
  final len = ByteData(4)..setUint32(0, data.length);
  final crc = ByteData(4)..setUint32(0, _crc32([...t, ...data]));
  return [
    ...len.buffer.asUint8List(),
    ...t,
    ...data,
    ...crc.buffer.asUint8List(),
  ];
}

final _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc32(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c = _crcTable[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}
