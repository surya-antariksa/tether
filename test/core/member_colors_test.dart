import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:tether/core/contrast.dart';
import 'package:tether/core/member_colors.dart';

void main() {
  test('palet berisi 8 warna hex #RRGGBB yang unik dan valid', () {
    expect(MemberColors.hexes, hasLength(8));
    expect(MemberColors.hexes.toSet(), hasLength(8));
    for (final h in MemberColors.hexes) {
      expect(MemberColors.isValid(h), isTrue, reason: h);
    }
    expect(MemberColors.hexes.first, '#0F766E');
    expect(MemberColors.defaultHex, MemberColors.hexes.first);
  });

  test('isValid sama dengan regex kontrak database', () {
    expect(MemberColors.isValid('#0f766e'), isTrue);
    expect(MemberColors.isValid('0F766E'), isFalse);
    expect(MemberColors.isValid('#0F766'), isFalse);
    expect(MemberColors.isValid('#0F766EE'), isFalse);
    expect(MemberColors.isValid('#GGGGGG'), isFalse);
  });

  test('toColor mengurai hex, hex rusak jatuh ke bawaan', () {
    expect(MemberColors.toColor('#2563EB'), const Color(0xFF2563EB));
    expect(MemberColors.toColor('xyz'), const Color(0xFF0F766E));
  });

  test('fungsi kontras WCAG: hitam di putih = 21, sama = 1', () {
    const white = Color(0xFFFFFFFF);
    const black = Color(0xFF000000);
    expect(contrastRatio(black, white), closeTo(21, 0.01));
    expect(contrastRatio(white, white), closeTo(1, 0.001));
  });

  test('teks inisial di atas tiap warna penanda >= 4,5:1', () {
    for (final h in MemberColors.hexes) {
      final ratio = contrastRatio(
        MemberColors.onColor(h),
        MemberColors.toColor(h),
      );
      expect(ratio, greaterThanOrEqualTo(4.5), reason: '$h = $ratio');
    }
  });
}
