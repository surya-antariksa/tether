import 'package:flutter_test/flutter_test.dart';
import 'package:tether/features/tracking/domain/tracking_status.dart';

void main() {
  group('TrackingStatus', () {
    test('memuat tujuh keadaan', () {
      expect(TrackingStatus.values, [
        TrackingStatus.idle,
        TrackingStatus.needsPermission,
        TrackingStatus.needsCircle,
        TrackingStatus.unavailable,
        TrackingStatus.running,
        TrackingStatus.offlineWithQueue,
        TrackingStatus.error,
      ]);
    });
  });

  group('TrackingSnapshot', () {
    test('nilai awal: idle dan semua hitungan nol', () {
      const s = TrackingSnapshot();
      expect(s.status, TrackingStatus.idle);
      expect(s.queued, 0);
      expect(s.sent, 0);
      expect(s.skippedByServer, 0);
      expect(s.dropped, 0);
      expect(s.droppedInvalid, 0);
      expect(s.lastError, isNull);
      expect(s.detail, isNull);
    });

    test('sama bila semua field sama, hashCode ikut sama', () {
      const a = TrackingSnapshot(
        status: TrackingStatus.running,
        queued: 1,
        sent: 2,
        skippedByServer: 3,
        dropped: 4,
        droppedInvalid: 5,
        lastError: 'x',
        detail: 'y',
      );
      const b = TrackingSnapshot(
        status: TrackingStatus.running,
        queued: 1,
        sent: 2,
        skippedByServer: 3,
        dropped: 4,
        droppedInvalid: 5,
        lastError: 'x',
        detail: 'y',
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(const TrackingSnapshot(), const TrackingSnapshot());
    });

    test('beda bila salah satu field berbeda', () {
      const base = TrackingSnapshot();
      final variants = <String, TrackingSnapshot>{
        'status': const TrackingSnapshot(status: TrackingStatus.error),
        'queued': const TrackingSnapshot(queued: 1),
        'sent': const TrackingSnapshot(sent: 1),
        'skippedByServer': const TrackingSnapshot(skippedByServer: 1),
        'dropped': const TrackingSnapshot(dropped: 1),
        'droppedInvalid': const TrackingSnapshot(droppedInvalid: 1),
        'lastError': const TrackingSnapshot(lastError: 'e'),
        'detail': const TrackingSnapshot(detail: 'd'),
      };
      variants.forEach((field, v) {
        expect(v == base, isFalse, reason: field);
        expect(base == v, isFalse, reason: field);
      });
    });

    test('tidak sama dengan objek bertipe lain', () {
      // ignore: unrelated_type_equality_checks
      expect(const TrackingSnapshot() == 'idle', isFalse);
    });
  });
}
