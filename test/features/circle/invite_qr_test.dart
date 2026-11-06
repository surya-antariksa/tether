import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:tether/features/circle/domain/circle.dart';
import 'package:tether/features/circle/domain/invite_code.dart';
import 'package:tether/features/circle/presentation/invite_sheet.dart';

import '../../support/fake_circle_repository.dart';
import '../../support/pump_circle.dart';

/// Jalur opsional untuk menyimpan QR yang dirender (dipakai skrip dekode).
const _dumpPath = String.fromEnvironment('QR_DUMP_PATH');

void main() {
  group('InviteCode QR', () {
    test('link memuat kode dan bisa dibaca balik', () {
      final link = InviteCode.link('ABC234');
      expect(link, 'tether://join?code=ABC234');
      expect(InviteCode.fromScan(link), 'ABC234');
    });

    test('fromScan menerima kode polos, huruf kecil, dan spasi', () {
      expect(InviteCode.fromScan('abc234'), 'ABC234');
      expect(InviteCode.fromScan('  ABC 234 '), 'ABC234');
    });

    test('fromScan menolak QR asing, kode pendek, dan null', () {
      expect(InviteCode.fromScan('https://contoh.com/abc'), isNull);
      expect(InviteCode.fromScan('tether://join?code=AB'), isNull);
      expect(InviteCode.fromScan('tether://join'), isNull);
      expect(InviteCode.fromScan('tether://lain?code=ABC234'), isNull);
      expect(InviteCode.fromScan(''), isNull);
      expect(InviteCode.fromScan(null), isNull);
    });
  });

  testWidgets('lembar undang menampilkan QR sungguhan berisi tautan kode', (
    tester,
  ) async {
    final repo = FakeCircleRepository(
      circles: [const Circle(id: 'c1', name: 'Keluarga')],
      members: {
        'c1': [fakeMember('user-1', 'Rina Wati', role: CircleRole.admin)],
      },
    );
    await pumpCircleApp(tester, repo: repo);
    await tester.tap(find.text('Undang'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('invite-qr')), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    final code =
        (tester.widget(find.byType(InviteSheet)) as InviteSheet).invite.code;
    final link = InviteCode.link(code);
    expect(InviteCode.fromScan(link), code);
    expect(
      QrValidator.validate(data: link, version: QrVersions.auto).status,
      QrValidationStatus.valid,
    );

    if (_dumpPath.isNotEmpty) {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('invite-qr')),
              matching: find.byType(RepaintBoundary),
            )
            .first,
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 4);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File(_dumpPath).writeAsBytesSync(bytes!.buffer.asUint8List());
        File('$_dumpPath.txt').writeAsStringSync(link);
      });
    }
  });
}
