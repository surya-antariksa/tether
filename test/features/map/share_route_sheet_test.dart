import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tether/app/theme/app_theme.dart';
import 'package:tether/features/map/presentation/share_route_sheet.dart';
import 'package:material_symbols_icons/symbols.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildSheet({
    String origin = 'Jl. Teuku Umar Barat',
    String destination = 'Jl. Raya Dalung No. 42',
    String distance = '3.8 km',
    String duration = '22 menit',
    String circleName = 'Lingkar Inti',
    List<ShareRouteMember>? members,
    ValueChanged<ShareRouteMember>? onSendMember,
    VoidCallback? onSendAll,
    ValueChanged<ShareExternalApp>? onExternalShare,
    VoidCallback? onCopyLink,
    double textScale = 1.0,
  }) {
    return CupertinoApp(
      theme: appTheme,
      home: Builder(
        builder: (context) => CupertinoPageScaffold(
          child: Center(
            child: CupertinoButton(
              child: const Text('Buka Sheet'),
              onPressed: () => showShareRouteSheet(
                context,
                origin: origin,
                destination: destination,
                distance: distance,
                duration: duration,
                circleName: circleName,
                members:
                    members ??
                    const [
                      ShareRouteMember(
                        id: '1',
                        name: 'Gita',
                        initial: 'G',
                        batteryPct: 88,
                        colorHex: '#00F2FE',
                      ),
                      ShareRouteMember(
                        id: '2',
                        name: 'Ibu',
                        initial: 'I',
                        batteryPct: 74,
                        colorHex: '#4EDEA3',
                      ),
                      ShareRouteMember(
                        id: '3',
                        name: 'Ayah',
                        initial: 'A',
                        batteryPct: 95,
                        colorHex: '#FFB347',
                      ),
                    ],
                onSendMember: onSendMember,
                onSendAll: onSendAll,
                onExternalShare: onExternalShare,
                onCopyLink: onCopyLink,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openSheet(
    WidgetTester tester, {
    String origin = 'Jl. Teuku Umar Barat',
    String destination = 'Jl. Raya Dalung No. 42',
    String distance = '3.8 km',
    String duration = '22 menit',
    String circleName = 'Lingkar Inti',
    List<ShareRouteMember>? members,
    ValueChanged<ShareRouteMember>? onSendMember,
    VoidCallback? onSendAll,
    ValueChanged<ShareExternalApp>? onExternalShare,
    VoidCallback? onCopyLink,
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = const Size(390, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      buildSheet(
        origin: origin,
        destination: destination,
        distance: distance,
        duration: duration,
        circleName: circleName,
        members: members,
        onSendMember: onSendMember,
        onSendAll: onSendAll,
        onExternalShare: onExternalShare,
        onCopyLink: onCopyLink,
        textScale: textScale,
      ),
    );
    await tester.tap(find.text('Buka Sheet'));
    await tester.pumpAndSettle();
  }

  testWidgets('menampilkan header, badge live, dan info ringkasan rute', (
    tester,
  ) async {
    await openSheet(tester);

    expect(find.text(ShareRouteStrings.title), findsOneWidget);
    expect(find.text(ShareRouteStrings.liveBadge), findsOneWidget);
    expect(find.text(ShareRouteStrings.subtitle), findsOneWidget);
    expect(find.text('Jl. Teuku Umar Barat'), findsOneWidget);
    expect(find.text('Jl. Raya Dalung No. 42'), findsOneWidget);
    expect(find.text('3.8 km'), findsOneWidget);
    expect(find.text('22 menit'), findsOneWidget);
    expect(find.text(ShareRouteStrings.safe), findsOneWidget);
  });

  testWidgets('aksi kirim anggota tunggal dan kirim semua anggota circle', (
    tester,
  ) async {
    ShareRouteMember? sentMember;
    bool sentAll = false;

    await openSheet(
      tester,
      onSendMember: (m) => sentMember = m,
      onSendAll: () => sentAll = true,
    );

    expect(find.text(ShareRouteStrings.circleSection), findsOneWidget);
    expect(find.text('Lingkar Inti'), findsOneWidget);
    expect(find.text('Gita'), findsOneWidget);
    expect(find.text('88%'), findsOneWidget);
    expect(find.text('Ibu'), findsOneWidget);
    expect(find.text('Ayah'), findsOneWidget);

    // Kirim ke Gita
    await tester.tap(find.widgetWithText(CupertinoButton, 'Kirim').first);
    await tester.pumpAndSettle();

    expect(sentMember?.id, '1');
    expect(find.text('Terkirim'), findsOneWidget);

    // Kirim ke semua
    await tester.tap(find.text(ShareRouteStrings.sendAll));
    await tester.pumpAndSettle();

    expect(sentAll, isTrue);
    expect(find.text('Terkirim'), findsNWidgets(3));
  });

  testWidgets('aplikasi eksternal memicu callback yang sesuai', (tester) async {
    ShareExternalApp? selectedApp;
    await openSheet(tester, onExternalShare: (app) => selectedApp = app);

    await tester.tap(find.text(ShareRouteStrings.whatsapp));
    await tester.pumpAndSettle();
    expect(selectedApp, ShareExternalApp.whatsApp);

    await tester.tap(find.text(ShareRouteStrings.telegram));
    await tester.pumpAndSettle();
    expect(selectedApp, ShareExternalApp.telegram);

    await tester.tap(find.text(ShareRouteStrings.smsSos));
    await tester.pumpAndSettle();
    expect(selectedApp, ShareExternalApp.smsSos);
  });

  testWidgets('pemilihan durasi tautan aktif mengubah seleksi', (tester) async {
    await openSheet(tester);

    expect(find.text(ShareRouteStrings.durationTitle), findsOneWidget);
    expect(find.text(ShareRouteStrings.duration1h), findsOneWidget);
    expect(find.text(ShareRouteStrings.duration6h), findsOneWidget);
    expect(find.text(ShareRouteStrings.duration24h), findsOneWidget);

    await tester.tap(find.text(ShareRouteStrings.duration24h));
    await tester.pumpAndSettle();

    await tester.tap(find.text(ShareRouteStrings.duration1h));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'salin tautan ringkasan menyalin ke clipboard dan memberi umpan balik',
    (tester) async {
      bool copyCalled = false;
      String? copiedData;

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            copiedData = (methodCall.arguments as Map)['text'] as String?;
            return null;
          }
          return null;
        },
      );

      await openSheet(tester, onCopyLink: () => copyCalled = true);

      await tester.tap(find.text(ShareRouteStrings.copySummaryCta));
      await tester.pumpAndSettle();

      expect(copyCalled, isTrue);
      expect(copiedData, contains('Jl. Teuku Umar Barat'));
      expect(copiedData, contains('Jl. Raya Dalung No. 42'));
      expect(find.text(ShareRouteStrings.copiedSuccess), findsOneWidget);
    },
  );

  testWidgets('tombol tutup menutup modal bottom sheet', (tester) async {
    await openSheet(tester);

    expect(find.byType(ShareRouteSheet), findsOneWidget);
    await tester.tap(find.byIcon(Symbols.close));
    await tester.pumpAndSettle();

    expect(find.byType(ShareRouteSheet), findsNothing);
  });

  testWidgets('aksesibilitas: label semantik dan ukuran sentuh tombol', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await openSheet(tester);

    expect(find.bySemanticsLabel('WhatsApp'), findsOneWidget);
    expect(find.bySemanticsLabel('Telegram'), findsOneWidget);
    expect(find.bySemanticsLabel('SMS SOS'), findsOneWidget);
    expect(find.bySemanticsLabel('Salin Tautan Ringkasan'), findsOneWidget);

    final ctaSize = tester.getSize(
      find.widgetWithText(CupertinoButton, ShareRouteStrings.copySummaryCta),
    );
    expect(ctaSize.height, greaterThanOrEqualTo(44));

    handle.dispose();
  });

  testWidgets('skala teks 2.0x tidak menimbulkan overflow layout', (
    tester,
  ) async {
    await openSheet(tester, textScale: 2.0);

    expect(tester.takeException(), isNull);
    expect(find.text(ShareRouteStrings.title), findsOneWidget);
    expect(find.text(ShareRouteStrings.copySummaryCta), findsOneWidget);
  });
}
