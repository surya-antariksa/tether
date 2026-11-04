import 'dart:math' as math;
import 'dart:ui';

/// Luminans relatif WCAG 2.x (0 hitam, 1 putih). Alfa diabaikan.
double relativeLuminance(Color c) {
  double lin(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
}

/// Rasio kontras WCAG. Bila [fg] transparan, dicampur dulu di atas [bg].
double contrastRatio(Color fg, Color bg) {
  final a = relativeLuminance(Color.alphaBlend(fg, bg));
  final b = relativeLuminance(bg);
  return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
}
