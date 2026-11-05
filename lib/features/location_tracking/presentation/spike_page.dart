import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/drift_point_queue.dart';
import '../data/location_api.dart';
import '../data/location_database.dart';
import '../data/location_uploader.dart';
import '../data/point_queue.dart';
import '../data/simulated_location_source.dart';
import '../data/tracking_controller.dart';

/// Halaman harness Sprint 0A: memutar rute simulasi dan melihat antrean
/// serta unggahan ke Supabase. Teks langsung bahasa Indonesia (l10n Sprint 1).
class SpikePage extends StatefulWidget {
  const SpikePage({
    super.key,
    required this.supabaseConfigured,
    this.apiFactory,
    this.queueFactory,
    this.ensureSession,
  });

  /// False bila SUPABASE_URL kosong: tombol mulai hanya menampilkan pesan.
  final bool supabaseConfigured;

  /// Pengganti untuk tes. Bawaan: Supabase dan SQLite sungguhan.
  final LocationApi Function()? apiFactory;
  final Future<PointQueue> Function()? queueFactory;
  final Future<void> Function()? ensureSession;

  @override
  State<SpikePage> createState() => _SpikePageState();
}

class _SpikePageState extends State<SpikePage> {
  TrackingController? _controller;
  FlakyLocationApi? _flaky;
  bool _offline = false;
  bool _starting = false;
  String? _message;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _ensureSession() async {
    final custom = widget.ensureSession;
    if (custom != null) return custom();
    final auth = Supabase.instance.client.auth;
    if (auth.currentSession == null) await auth.signInAnonymously();
  }

  Future<TrackingController> _build() async {
    final api =
        widget.apiFactory?.call() ??
        SupabaseLocationApi(Supabase.instance.client);
    final flaky = FlakyLocationApi(api)..offline = _offline;
    final queue =
        await (widget.queueFactory?.call() ??
            LocationDatabase.openDefault().then(DriftPointQueue.new));
    final uploader = LocationUploader(
      queue: queue,
      api: flaky,
      log: (m) => debugPrint('[uploader] $m'),
    );
    final source = SimulatedLocationSource(onCompleted: _stop);
    _flaky = flaky;
    return TrackingController(source: source, queue: queue, uploader: uploader);
  }

  Future<void> _start() async {
    if (_starting) return;
    if (!widget.supabaseConfigured) {
      setState(
        () => _message =
            'SUPABASE_URL kosong. Jalankan dengan --dart-define=SUPABASE_URL=... '
            'dan --dart-define=SUPABASE_ANON_KEY=...',
      );
      return;
    }
    setState(() {
      _starting = true;
      _message = null;
    });
    try {
      await _ensureSession();
      final controller = _controller ??= await _build();
      await controller.start();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _message = 'Gagal memulai: ${e.runtimeType}');
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _stop() async {
    await _controller?.stop();
  }

  void _setOffline(bool value) {
    setState(() => _offline = value);
    _flaky?.offline = value;
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Tether: uji pelacakan'),
      ),
      child: SafeArea(
        child: ListenableBuilder(
          listenable: controller ?? const _NoChange(),
          builder: (context, _) {
            final s = controller?.state ?? const TrackingState();
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                CupertinoButton.filled(
                  onPressed: _starting || s.running ? null : _start,
                  child: const Text('Mulai rute simulasi'),
                ),
                const SizedBox(height: 8),
                CupertinoButton(
                  onPressed: s.running ? _stop : null,
                  child: const Text('Berhenti'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Expanded(child: Text('Putuskan jaringan (simulasi)')),
                    CupertinoSwitch(value: _offline, onChanged: _setOffline),
                  ],
                ),
                const SizedBox(height: 16),
                _row('Status', _statusText(s)),
                _row('Antrean', '${s.queued}'),
                _row('Terkirim', '${s.sent}'),
                if (s.skippedByServer > 0)
                  _row(
                    'Dilewati server (duplikat atau terlalu lama)',
                    '${s.skippedByServer}',
                  ),
                if (s.dropped > 0)
                  _row('Dibuang (antrean penuh)', '${s.dropped}'),
                if (s.droppedInvalid > 0)
                  _row('Dibuang (data tidak valid)', '${s.droppedInvalid}'),
                _row('Kesalahan terakhir', s.lastError ?? '-'),
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _message!,
                      style: const TextStyle(color: CupertinoColors.systemRed),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _statusText(TrackingState s) {
    if (s.backoff > Duration.zero) {
      return 'Gagal kirim, coba lagi dalam ${s.backoff.inSeconds} detik';
    }
    return s.running ? 'Berjalan' : 'Berhenti';
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label)),
        Flexible(child: Text(value, textAlign: TextAlign.end)),
      ],
    ),
  );
}

/// Listenable kosong untuk ListenableBuilder sebelum controller dibuat.
class _NoChange implements Listenable {
  const _NoChange();

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}
