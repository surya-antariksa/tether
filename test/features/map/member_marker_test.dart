import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tether/app/theme/app_theme.dart';
import 'package:tether/features/map/domain/presence.dart';
import 'package:tether/features/map/domain/vehicle_type.dart';
import 'package:tether/features/map/presentation/member_marker.dart';
import 'package:material_symbols_icons/symbols.dart';

Future<int Function()> pumpMarker(
  WidgetTester tester, {
  String name = 'Rina Wati',
  String colorHex = '#0F766E',
  PresenceState presence = PresenceState.active,
  bool isSelf = false,
  bool? isMoving,
  VehicleType vehicle = VehicleType.none,
  double? speedKmh,
  String label = 'Rina Wati, Aktif',
  double textScale = 1.0,
}) async {
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  var taps = 0;
  await tester.pumpWidget(
    CupertinoApp(
      theme: appTheme,
      home: CupertinoPageScaffold(
        child: Center(
          child: MemberMarker(
            name: name,
            colorHex: colorHex,
            presence: presence,
            isSelf: isSelf,
            isMoving: isMoving,
            vehicle: vehicle,
            speedKmh: speedKmh,
            semanticLabel: label,
            onTap: () => taps++,
          ),
        ),
      ),
    ),
  );
  return () => taps;
}

double opacityOf(WidgetTester tester) => tester
    .widget<Opacity>(
      find.descendant(
        of: find.byType(MemberMarker),
        matching: find.byType(Opacity),
      ),
    )
    .opacity;

void main() {
  testWidgets('anggota lain: inisial di avatar, nama di label', (tester) async {
    await pumpMarker(tester);

    expect(find.text('RW'), findsOneWidget); // inisial
    expect(find.text('Rina Wati'), findsOneWidget); // label nama
    expect(find.text('Kamu'), findsNothing);
  });

  testWidgets('diri sendiri: label "Kamu" menggantikan nama', (tester) async {
    await pumpMarker(tester, isSelf: true);

    expect(find.text('Kamu'), findsOneWidget);
    expect(find.text('Rina Wati'), findsNothing);
    expect(find.text('RW'), findsOneWidget);
  });

  testWidgets('diri sendiri memakai cincin tint tebal, lainnya putih tipis', (
    tester,
  ) async {
    BoxDecoration ring() {
      final c = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(MemberMarker),
              matching: find.byWidgetPredicate(
                (w) =>
                    w is Container &&
                    w.decoration is BoxDecoration &&
                    (w.decoration! as BoxDecoration).shape == BoxShape.circle &&
                    (w.decoration! as BoxDecoration).border != null,
              ),
            )
            .first,
      );
      return c.decoration! as BoxDecoration;
    }

    await pumpMarker(tester);
    final other = ring().border! as Border;
    expect(other.top.width, 2);
    expect(other.top.color, CupertinoColors.white);

    await pumpMarker(tester, isSelf: true);
    final self = ring().border! as Border;
    expect(self.top.width, 3);
    expect(self.top.color, isNot(CupertinoColors.white));
  });

  testWidgets('ikon gerak: bergerak, diam, atau tanpa lencana', (tester) async {
    await pumpMarker(tester, isMoving: true);
    expect(find.byIcon(Symbols.near_me), findsOneWidget);
    expect(find.byIcon(Symbols.radio_button_checked), findsNothing);

    await pumpMarker(tester, isMoving: false);
    expect(find.byIcon(Symbols.radio_button_checked), findsOneWidget);
    expect(find.byIcon(Symbols.near_me), findsNothing);

    await pumpMarker(tester, isMoving: null);
    expect(find.byIcon(Symbols.radio_button_checked), findsNothing);
    expect(find.byIcon(Symbols.near_me), findsNothing);
  });

  testWidgets('badge kendaraan: motor dan mobil di atas marker', (
    tester,
  ) async {
    await pumpMarker(
      tester,
      isMoving: true,
      vehicle: VehicleType.motorcycle,
      speedKmh: 35,
    );
    expect(find.byIcon(Symbols.two_wheeler), findsOneWidget);
    expect(find.text('35 km/j'), findsOneWidget);

    await pumpMarker(
      tester,
      isMoving: true,
      vehicle: VehicleType.car,
      speedKmh: 60,
    );
    expect(find.byIcon(Symbols.directions_car), findsOneWidget);
    expect(find.text('60 km/j'), findsOneWidget);
  });

  testWidgets('basi dipudarkan setengah, aktif penuh', (tester) async {
    await pumpMarker(tester, presence: PresenceState.active);
    expect(opacityOf(tester), 1);

    await pumpMarker(tester, presence: PresenceState.stale);
    expect(opacityOf(tester), 0.5);
  });

  testWidgets('ukuran kotak 96 dan area sentuh 44x44', (tester) async {
    await pumpMarker(tester);

    expect(tester.getSize(find.byType(MemberMarker)), const Size(96, 96));
    final hit = find.descendant(
      of: find.byType(MemberMarker),
      matching: find.byType(GestureDetector),
    );
    expect(tester.getSize(hit), const Size(44, 44));
  });

  testWidgets('ketuk memanggil onTap', (tester) async {
    final taps = await pumpMarker(tester);

    await tester.tap(find.text('RW'));
    await tester.tap(find.byType(GestureDetector).first);
    expect(taps(), 2);
  });

  testWidgets('Semantics: tombol dengan label yang diberikan', (tester) async {
    final handle = tester.ensureSemantics();
    final taps = await pumpMarker(
      tester,
      label: 'Rina Wati, Terakhir terlihat 2 jam lalu',
      presence: PresenceState.stale,
    );

    expect(
      find.bySemanticsLabel('Rina Wati, Terakhir terlihat 2 jam lalu'),
      findsOneWidget,
    );
    final node = tester.getSemantics(
      find.bySemanticsLabel('Rina Wati, Terakhir terlihat 2 jam lalu'),
    );
    expect(node.flagsCollection.isButton, isTrue);
    tester.semantics.tap(
      find.semantics.byLabel('Rina Wati, Terakhir terlihat 2 jam lalu'),
    );
    expect(taps(), 1);
    handle.dispose();
  });

  testWidgets('nama panjang dipotong di label, tidak meluap', (tester) async {
    await pumpMarker(
      tester,
      name: 'Raden Mas Bagus Prasetyo Hadiningrat Kusumawardhana',
      textScale: 2.0,
    );

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(MemberMarker)), const Size(96, 96));
  });

  testWidgets('warna hex tidak valid tidak melempar (jatuh ke bawaan)', (
    tester,
  ) async {
    await pumpMarker(tester, colorHex: 'bukan-warna');

    expect(tester.takeException(), isNull);
    expect(find.text('RW'), findsOneWidget);
  });
}
