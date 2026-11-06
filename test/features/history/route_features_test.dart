import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:tether/features/history/domain/history_point.dart';
import 'package:tether/features/history/domain/route_stats.dart';
import 'package:tether/features/history/presentation/point_detail_page.dart';
import 'package:tether/features/history/presentation/route_compare_page.dart';
import 'package:tether/features/history/presentation/route_playback_page.dart';
import 'package:tether/features/history/presentation/route_strings.dart';

import '../profile/profile_harness.dart';

HistoryPoint pt(
  DateTime t,
  double lat,
  double lng, {
  bool moving = true,
  double? speedMps,
}) => HistoryPoint(
  point: LatLng(lat, lng),
  recordedAt: t,
  isMoving: moving,
  speedMps: speedMps,
);

void main() {
  final t0 = DateTime(2026, 11, 5, 8, 0, 0);

  group('RouteStats', () {
    test('kosong menghasilkan nol', () {
      final s = RouteStats.of(const []);
      expect(s.count, 0);
      expect(s.distanceM, 0);
      expect(s.avgSpeedKmh, 0);
    });

    test('jarak, durasi, kecepatan dari titik bergerak', () {
      // ~111 m ke utara tiap 10 detik = ~40 km/jam.
      final pts = [
        for (var i = 0; i < 4; i++)
          pt(t0.add(Duration(seconds: i * 10)), -6.2 + i * 0.001, 106.8),
      ];
      final s = RouteStats.of(pts);
      expect(s.count, 4);
      expect(s.distanceM, closeTo(333, 5));
      expect(s.duration, const Duration(seconds: 30));
      expect(s.movingDuration, const Duration(seconds: 30));
      expect(s.avgSpeedKmh, closeTo(40, 1.5));
      expect(s.maxSpeedKmh, closeTo(40, 1.5));
    });

    test('kecepatan GPS dipakai bila ada', () {
      final pts = [
        pt(t0, -6.2, 106.8, speedMps: 5),
        pt(t0.add(const Duration(seconds: 10)), -6.2005, 106.8, speedMps: 10),
      ];
      expect(RouteStats.of(pts).maxSpeedKmh, closeTo(36, 0.1));
    });

    test('selang lebih dari 10 menit tidak dihitung ke jarak', () {
      final pts = [
        pt(t0, -6.2, 106.8),
        pt(t0.add(const Duration(minutes: 30)), -6.3, 106.9),
      ];
      final s = RouteStats.of(pts);
      expect(s.distanceM, 0);
      expect(s.movingDuration, Duration.zero);
      expect(s.duration, const Duration(minutes: 30));
    });

    test('titik diam tidak menambah jarak', () {
      final pts = [
        pt(t0, -6.2, 106.8, moving: false),
        pt(t0.add(const Duration(seconds: 30)), -6.2001, 106.8, moving: false),
      ];
      expect(RouteStats.of(pts).distanceM, 0);
    });
  });

  test('groupByDay: hari terbaru dulu, urut waktu naik di dalam hari', () {
    final g = groupByDay([
      pt(DateTime(2026, 11, 5, 10), 0, 0),
      pt(DateTime(2026, 11, 4, 9), 0, 0),
      pt(DateTime(2026, 11, 5, 8), 0, 0),
    ]);
    expect(g.map((e) => e.$1.day), [5, 4]);
    expect(g.first.$2.first.recordedAt.hour, 8);
  });

  group('halaman riwayat', () {
    testWidgets('ketuk titik membuka Detail Titik dengan koordinat', (
      tester,
    ) async {
      await pumpProfile(
        tester,
        history: FakeHistoryRepository(points: sampleHistory()),
        initial: '/profile/history',
      );
      await tester.ensureVisible(find.text('11.45'));
      await tester.tap(find.text('11.45'));
      await tester.pumpAndSettle();

      expect(find.byType(PointDetailPage), findsOneWidget);
      expect(find.text('-6.19000, 106.81670'), findsOneWidget);
      expect(find.text(RouteStrings.movingLabel), findsOneWidget);
      // Akurasi 12 m tercatat; baterai tidak tercatat.
      expect(find.text('±12 m'), findsOneWidget);
      expect(find.text(RouteStrings.unavailable), findsWidgets);
    });

    testWidgets('Putar Rute membuka pemutar dan bisa dimulai', (tester) async {
      await pumpProfile(
        tester,
        history: FakeHistoryRepository(points: sampleHistory()),
        initial: '/profile/history',
      );
      await tester.ensureVisible(find.text(RouteStrings.play));
      await tester.tap(find.text(RouteStrings.play));
      await tester.pumpAndSettle();

      expect(find.byType(RoutePlaybackPage), findsOneWidget);
      expect(find.text(RouteStrings.statsTitle.toUpperCase()), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel(RouteStrings.resume));
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      // Sudah berjalan: persen naik dan tombol berubah menjadi Jeda.
      expect(find.text('0%'), findsNothing);
      expect(find.bySemanticsLabel(RouteStrings.pause), findsOneWidget);
      await tester.tap(find.bySemanticsLabel(RouteStrings.pause));
      await tester.pumpAndSettle();
    });

    testWidgets('Bandingkan membuka perbandingan dua hari', (tester) async {
      await pumpProfile(
        tester,
        history: FakeHistoryRepository(points: sampleHistory()),
        initial: '/profile/history',
      );
      await tester.ensureVisible(find.text(RouteStrings.compare));
      await tester.tap(find.text(RouteStrings.compare));
      await tester.pumpAndSettle();

      expect(find.byType(RouteComparePage), findsOneWidget);
      expect(find.text(RouteStrings.dayA), findsOneWidget);
      expect(find.text(RouteStrings.dayB), findsOneWidget);
      expect(find.text(RouteStrings.deltaTitle.toUpperCase()), findsOneWidget);
    });
  });
}
