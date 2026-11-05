import 'dart:async';

import 'package:tether/features/safety/data/safety_providers.dart';
import 'package:tether/features/safety/domain/safety_error.dart';
import 'package:tether/features/safety/domain/safety_repository.dart';
import 'package:tether/features/safety/domain/sos_location.dart';
import 'package:tether/features/safety/domain/sos_models.dart';

/// Satu panggilan trigger_sos yang diterima repository palsu.
class SosCall {
  SosCall(this.lat, this.lng, this.accuracyM, this.clientId, this.triggeredAt);

  final double lat;
  final double lng;
  final double? accuracyM;
  final String clientId;
  final DateTime triggeredAt;
}

/// Repository palsu dengan jawaban berskrip. Meniru idempotensi server:
/// clientId yang sudah pernah berhasil mengembalikan hasil lama tanpa
/// menambah [eventsCreated].
class FakeSafetyRepository implements SafetyRepository {
  /// Jawaban SOS berikutnya (dikonsumsi berurutan); bila habis, sukses [circles].
  final List<Object> sosScript = [];
  int circles = 2;

  /// Gerbang untuk menahan jawaban (tes keadaan memuat).
  Completer<void>? gate;

  final sosCalls = <SosCall>[];
  final checkinCalls = <(String, CheckinKind)>[];
  final _done = <String>{};
  int eventsCreated = 0;

  /// Jawaban check-in berikutnya: SafetyError dilempar, null sukses.
  SafetyErrorKind? checkinFailure;

  @override
  Future<void> checkin(String circleId, CheckinKind kind) async {
    checkinCalls.add((circleId, kind));
    if (gate != null) await gate!.future;
    if (checkinFailure != null) throw SafetyError(checkinFailure!);
  }

  @override
  Future<int> triggerSos({
    required double lat,
    required double lng,
    double? accuracyM,
    required String clientId,
    required DateTime triggeredAt,
  }) async {
    sosCalls.add(SosCall(lat, lng, accuracyM, clientId, triggeredAt));
    if (gate != null) await gate!.future;
    if (sosScript.isNotEmpty) {
      final next = sosScript.removeAt(0);
      if (next is SafetyErrorKind) throw SafetyError(next);
      if (next is Exception) throw next;
    }
    if (_done.add(clientId)) eventsCreated += circles;
    return circles;
  }
}

class FakeSosLocation implements SosLocationProvider {
  FakeSosLocation({this.currentFix, this.last});

  SosFix? currentFix;
  SosFix? last;

  /// Bila diisi, current() menunggu ini (tes batas waktu).
  Completer<SosFix?>? currentGate;

  /// Bila diisi, lastKnown() menunggu ini.
  Completer<SosFix?>? lastGate;
  int currentCalls = 0;

  @override
  Future<SosFix?> current() {
    currentCalls++;
    if (currentGate != null) return currentGate!.future;
    return Future.value(currentFix);
  }

  @override
  Future<SosFix?> lastKnown() {
    if (lastGate != null) return lastGate!.future;
    return Future.value(last);
  }
}

/// Haptic palsu: hanya menghitung.
class FakeHaptics implements SosHaptics {
  int holdTicks = 0;
  int holdCompletes = 0;
  int countdownTicks = 0;

  @override
  void holdTick() => holdTicks++;

  @override
  void holdComplete() => holdCompletes++;

  @override
  void countdownTick() => countdownTicks++;
}

const jakarta = SosFix(lat: -6.2088, lng: 106.8456, accuracyM: 12);
