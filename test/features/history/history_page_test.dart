import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tether/features/history/domain/history_repository.dart';
import 'package:tether/features/history/presentation/history_page.dart';

import '../profile/profile_harness.dart';

Finder inDialog(String text) => find.descendant(
  of: find.byType(CupertinoAlertDialog),
  matching: find.text(text),
);

Future<ProfileHarness> openHistory(
  WidgetTester tester, {
  FakeHistoryRepository? history,
  bool settle = true,
  double textScale = 1.0,
}) => pumpProfile(
  tester,
  history: history ?? FakeHistoryRepository(points: sampleHistory()),
  initial: '/profile/history',
  settle: settle,
  textScale: textScale,
);

void main() {
  testWidgets('memuat: indikator aktivitas, belum ada daftar', (tester) async {
    final gate = Completer<void>();
    final repo = FakeHistoryRepository(points: sampleHistory())..gate = gate;
    await openHistory(tester, history: repo, settle: false);
    await tester.pump();

    expect(find.byType(HistoryPage), findsOneWidget);
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    expect(find.text('Hapus riwayat'), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('3 titik dalam 48 jam terakhir'), findsOneWidget);
  });

  testWidgets('kosong: pesan, keterangan privasi, tanpa tombol hapus', (
    tester,
  ) async {
    await openHistory(tester, history: FakeHistoryRepository());

    expect(find.text('Belum ada riwayat'), findsOneWidget);
    expect(find.textContaining('disimpan 48 jam'), findsOneWidget);
    expect(find.text('Hapus riwayat'), findsNothing);
    expect(find.byType(FlutterMap), findsNothing);
  });

  testWidgets('galat: pesan dan Coba lagi memuat ulang', (tester) async {
    final repo = FakeHistoryRepository(points: sampleHistory())
      ..fetchFailure = const HistoryFailure(HistoryFailureKind.network);
    await openHistory(tester, history: repo);

    expect(find.text('Riwayat tidak bisa dimuat.'), findsOneWidget);
    repo.fetchFailure = null;
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();

    expect(repo.fetchCalls, 2);
    expect(find.text('3 titik dalam 48 jam terakhir'), findsOneWidget);
  });

  testWidgets('sukses: peta ringkas, daftar per hari, tanpa jaringan', (
    tester,
  ) async {
    final h = await openHistory(tester);

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byType(PolylineLayer), findsOneWidget);
    expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
    // Tile hanya lewat penyedia palsu (tidak ada jaringan).
    expect(h.tiles.requests, greaterThan(0));

    expect(find.text('HARI INI'), findsOneWidget);
    expect(find.text('KEMARIN'), findsOneWidget);
    expect(find.text('11.45'), findsOneWidget);
    expect(find.text('09.05'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('22.30'), 100);
    expect(find.text('22.30'), findsOneWidget);
    expect(find.text('Bergerak, akurasi ±12 m'), findsOneWidget);
    expect(find.text('Diam, akurasi ±12 m'), findsOneWidget);
    expect(find.text('Diam'), findsOneWidget); // tanpa akurasi
    // Koordinat mentah tidak ditampilkan di daftar.
    expect(find.textContaining('106.81'), findsNothing);
  });

  testWidgets(
    'hapus: batal tidak menghapus; konfirmasi menghapus lalu kosong',
    (tester) async {
      final h = await openHistory(tester);

      await tester.tap(find.text('Hapus riwayat'));
      await tester.pumpAndSettle();
      expect(inDialog('Hapus riwayat lokasi?'), findsOneWidget);

      await tester.tap(inDialog('Batal'));
      await tester.pumpAndSettle();
      expect(h.history.deleteCalls, 0);
      expect(find.text('3 titik dalam 48 jam terakhir'), findsOneWidget);

      await tester.tap(find.text('Hapus riwayat'));
      await tester.pumpAndSettle();
      await tester.tap(inDialog('Hapus riwayat'));
      await tester.pumpAndSettle();

      expect(h.history.deleteCalls, 1);
      expect(inDialog('3 titik lokasi sudah dihapus.'), findsOneWidget);
      await tester.tap(inDialog('Tutup'));
      await tester.pumpAndSettle();
      expect(find.text('Belum ada riwayat'), findsOneWidget);
    },
  );

  testWidgets('hapus gagal: pesan galat, daftar tetap, tombol aktif lagi', (
    tester,
  ) async {
    final repo = FakeHistoryRepository(points: sampleHistory())
      ..deleteFailure = const HistoryFailure(HistoryFailureKind.network);
    await openHistory(tester, history: repo);

    await tester.tap(find.text('Hapus riwayat'));
    await tester.pumpAndSettle();
    await tester.tap(inDialog('Hapus riwayat'));
    await tester.pumpAndSettle();

    expect(inDialog('Gagal menghapus'), findsOneWidget);
    expect(
      inDialog('Tidak bisa terhubung. Periksa koneksi internet Anda.'),
      findsOneWidget,
    );
    await tester.tap(inDialog('Tutup'));
    await tester.pumpAndSettle();
    expect(find.text('3 titik dalam 48 jam terakhir'), findsOneWidget);
    final button = tester.widget<CupertinoButton>(
      find.widgetWithText(CupertinoButton, 'Hapus riwayat'),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('aksesibilitas: label semantik, area sentuh 44 pt', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await openHistory(tester);

    expect(
      find.bySemanticsLabel('Peta jejak lokasi Anda dalam 48 jam terakhir'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Pukul 11.45, bergerak, akurasi ±12 m'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(find.text('22.30'), 100);
    expect(find.bySemanticsLabel('Pukul 22.30, diam'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Hapus riwayat')),
      matchesSemantics(
        label: 'Hapus riwayat',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester
          .getSize(find.widgetWithText(CupertinoButton, 'Hapus riwayat'))
          .height,
      greaterThanOrEqualTo(44),
    );
    handle.dispose();
  });

  testWidgets('skala teks besar tidak menimbulkan overflow', (tester) async {
    await openHistory(tester, textScale: 2.0);
    expect(tester.takeException(), isNull);
    expect(find.text('Hapus riwayat'), findsOneWidget);
  });
}
