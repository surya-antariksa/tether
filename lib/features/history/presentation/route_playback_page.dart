import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/design_widgets.dart';
import '../../../core/widgets/glass_card.dart';
import '../../map/data/map_providers.dart';
import '../../map/presentation/map_theme.dart';
import '../../map/presentation/members_map.dart' show kUserAgentPackageName;
import '../../map/presentation/osm_attribution.dart';
import '../domain/history_point.dart';
import '../domain/route_stats.dart';
import 'route_strings.dart';

/// Memutar ulang jejak (urut waktu NAIK) di peta: penanda bergerak mengikuti
/// waktu tercatat, lengkap dengan kecepatan, ringkasan, dan perhentian.
/// Semua nilai berasal dari titik riwayat; tidak ada yang dikarang.
class RoutePlaybackPage extends ConsumerStatefulWidget {
  const RoutePlaybackPage({super.key, required this.points, this.title});

  /// Urut waktu naik, minimal 2 titik agar ada yang diputar.
  final List<HistoryPoint> points;
  final String? title;

  @override
  ConsumerState<RoutePlaybackPage> createState() => _RoutePlaybackPageState();
}

class _RoutePlaybackPageState extends ConsumerState<RoutePlaybackPage>
    with SingleTickerProviderStateMixin {
  /// Lama putar 1x untuk seluruh rute.
  static const _baseSeconds = 30;

  late final List<HistoryPoint> _pts = widget.points;
  late final RouteStats _stats = RouteStats.of(_pts);
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: _baseSeconds),
  )..addListener(() => setState(() {}));
  final _map = MapController();
  int _speed = 1;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _ctl.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        setState(() => _playing = false);
      }
    });
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_pts.length < 2) return;
    if (_playing) {
      _ctl.stop();
      setState(() => _playing = false);
    } else {
      if (_ctl.value >= 1) _ctl.value = 0;
      _ctl.forward();
      setState(() => _playing = true);
    }
  }

  void _setSpeed(int s) {
    final was = _playing;
    final v = _ctl.value;
    setState(() => _speed = s);
    _ctl.duration = Duration(milliseconds: _baseSeconds * 1000 ~/ s);
    _ctl.value = v;
    if (was) _ctl.forward();
  }

  void _restart() {
    _ctl.value = 0;
    setState(() => _playing = false);
    _ctl.stop();
  }

  /// Waktu virtual kumulatif (detik) di tiap titik. Selang yang lebih dari
  /// [RouteStats.maxGap] (jeda panjang) dipadatkan jadi 1 detik agar putar
  /// tidak diam lama di antara dua perjalanan.
  late final List<double> _cum = () {
    final out = <double>[0];
    for (var i = 1; i < _pts.length; i++) {
      final dt = _pts[i].recordedAt.difference(_pts[i - 1].recordedAt);
      final v = dt <= Duration.zero
          ? 0.001
          : (dt > RouteStats.maxGap ? 1.0 : dt.inMilliseconds / 1000);
      out.add(out.last + math.max(v, 0.001));
    }
    return out;
  }();

  /// Indeks titik terakhir yang waktu virtualnya <= [v].
  int _indexAtVirtual(double v) {
    var lo = 0;
    var hi = _pts.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (_cum[mid] <= v) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  /// Fraksi (0..1) di dalam selang [i, i+1] pada waktu virtual [v].
  double _fraction(double v, int i) {
    if (i >= _pts.length - 1) return 0;
    final span = _cum[i + 1] - _cum[i];
    return span <= 0 ? 0 : ((v - _cum[i]) / span).clamp(0.0, 1.0);
  }

  DateTime _timeAt(int i, double f) {
    if (i >= _pts.length - 1) return _pts.last.recordedAt;
    final a = _pts[i].recordedAt;
    final b = _pts[i + 1].recordedAt;
    return a.add(
      Duration(microseconds: (b.difference(a).inMicroseconds * f).round()),
    );
  }

  LatLng _positionAt(int i, double f) {
    if (i >= _pts.length - 1) return _pts.last.point;
    final a = _pts[i];
    final b = _pts[i + 1];
    final gap = b.recordedAt.difference(a.recordedAt);
    // Selang panjang = jeda; tetap di titik awal selang (tidak "terbang").
    if (gap <= Duration.zero || gap > RouteStats.maxGap) return a.point;
    return LatLng(
      a.point.latitude + (b.point.latitude - a.point.latitude) * f,
      a.point.longitude + (b.point.longitude - a.point.longitude) * f,
    );
  }

  String _title() {
    if (_pts.isEmpty) return RouteStrings.playbackTitle;
    final d = _pts.first.recordedAt;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${RouteStrings.playbackTitle} ${two(d.day)}/${two(d.month)}';
  }

  static String _clock(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}.${two(t.minute)}.${two(t.second)}';
  }

  /// Perhentian: titik berurutan yang diam dan berselang >= 5 menit.
  List<(DateTime, int)> _stops() {
    final out = <(DateTime, int)>[];
    int? startI;
    for (var i = 0; i < _pts.length; i++) {
      final still = !_pts[i].isMoving;
      if (still && startI == null) startI = i;
      final endRun = !still || i == _pts.length - 1;
      if (endRun && startI != null) {
        final endI = still ? i : i - 1;
        final mins = _pts[endI].recordedAt
            .difference(_pts[startI].recordedAt)
            .inMinutes;
        if (mins >= 5) out.add((_pts[startI].recordedAt, mins));
        startI = null;
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final tint = AppColors.tint.resolveFrom(context);
    final dim = AppColors.textTertiary.resolveFrom(context);
    final t = _ctl.value;
    final v = _pts.length < 2 ? 0.0 : t * _cum.last;
    final i = _pts.length < 2 ? 0 : _indexAtVirtual(v);
    final f = _pts.length < 2 ? 0.0 : _fraction(v, i);
    final at = _pts.isEmpty ? DateTime.now() : _timeAt(i, f);
    final pos = _pts.isEmpty ? const LatLng(0, 0) : _positionAt(i, f);
    final cur = _pts.isEmpty ? null : _pts[i];
    final stops = _stops();
    final tiles = ref.watch(mapTileProviderProvider);
    final full = [for (final p in _pts) p.point];
    final done = <LatLng>[...full.take(i + 1), pos];

    final map = _pts.length < 2
        ? const SizedBox.shrink()
        : FlutterMap(
            mapController: _map,
            options: MapOptions(
              backgroundColor: mapBackground(context),
              initialCameraFit: CameraFit.coordinates(
                coordinates: full,
                padding: const EdgeInsets.all(40),
                maxZoom: 17,
              ),
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
              ),
            ),
            children: [
              ThemedTileLayer(
                userAgentPackageName: kUserAgentPackageName,
                tileProvider: tiles,
              ),
              PolylineLayer(
                polylines: [
                  Polyline(points: full, strokeWidth: 4, color: dim),
                  Polyline(points: done, strokeWidth: 5, color: tint),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: full.first,
                    width: 14,
                    height: 14,
                    child: _Dot(
                      color: AppColors.success.resolveFrom(context),
                      ring: AppColors.background.resolveFrom(context),
                    ),
                  ),
                  Marker(
                    point: full.last,
                    width: 14,
                    height: 14,
                    child: _Dot(
                      color: AppColors.danger.resolveFrom(context),
                      ring: AppColors.background.resolveFrom(context),
                    ),
                  ),
                  Marker(
                    point: pos,
                    width: 30,
                    height: 30,
                    child: _Cursor(
                      color: tint,
                      ring: AppColors.background.resolveFrom(context),
                      glow: AppColors.isDark(context),
                    ),
                  ),
                ],
              ),
            ],
          );

    return CupertinoPageScaffold(
      backgroundColor: AppColors.groupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text(widget.title ?? _title()),
      ),
      child: AtmosphereBackground(
        child: SafeArea(
          child: _pts.length < 2
              ? Center(
                  child: Text(
                    RouteStrings.noData,
                    style: AppTextStyles.body(
                      context,
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: SizedBox(
                        height: 280,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: ExcludeSemantics(child: map),
                            ),
                            Positioned(
                              left: 10,
                              top: 10,
                              child: _Chip(
                                icon: Symbols.schedule,
                                text: _clock(at),
                              ),
                            ),
                            Positioned(
                              right: 10,
                              top: 10,
                              child: _Chip(
                                icon: Symbols.speed,
                                text: cur?.speedKmh == null
                                    ? (cur?.isMoving == true
                                          ? RouteStrings.movingLabel
                                          : RouteStrings.stillLabel)
                                    : '${cur!.speedKmh!.round()} ${RouteStrings.kmh}',
                              ),
                            ),
                            const Positioned(
                              left: 6,
                              bottom: 4,
                              child: OsmAttribution(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Text(
                                _clock(_pts.first.recordedAt),
                                style: AppTextStyles.caption1(
                                  context,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${(t * 100).round()}%',
                                style: AppTextStyles.caption1(
                                  context,
                                  emphasized: true,
                                  color: AppColors.tint,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                _clock(_pts.last.recordedAt),
                                style: AppTextStyles.caption1(
                                  context,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          Semantics(
                            label: RouteStrings.progressLabel,
                            value: '${(t * 100).round()}%',
                            child: CupertinoSlider(
                              value: t,
                              onChangeStart: (_) {
                                _ctl.stop();
                                setState(() => _playing = false);
                              },
                              onChanged: (v) => _ctl.value = v,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _RoundButton(
                                icon: Symbols.replay,
                                label: RouteStrings.restart,
                                onTap: _restart,
                              ),
                              const SizedBox(width: 20),
                              _RoundButton(
                                icon: _playing
                                    ? Symbols.pause
                                    : Symbols.play_arrow,
                                label: _playing
                                    ? RouteStrings.pause
                                    : RouteStrings.resume,
                                onTap: _toggle,
                                big: true,
                              ),
                              const SizedBox(width: 20),
                              for (final s in const [1, 2, 4]) ...[
                                _SpeedPill(
                                  label: '${s}x',
                                  selected: _speed == s,
                                  onTap: () => _setSpeed(s),
                                ),
                                const SizedBox(width: 6),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    SectionLabel(RouteStrings.statsTitle),
                    const SizedBox(height: 10),
                    _StatsGrid(stats: _stats),
                    const SizedBox(height: 18),
                    SectionLabel(
                      RouteStrings.stopsTitle,
                      trailing: Text(
                        RouteStrings.stopsCount(stops.length),
                        style: AppTextStyles.caption2(
                          context,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    GlassCard(
                      padding: const EdgeInsets.all(14),
                      child: stops.isEmpty
                          ? Text(
                              RouteStrings.stopsNone,
                              style: AppTextStyles.footnote(
                                context,
                                color: AppColors.textSecondary,
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final (start, mins) in stops)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Symbols.pause_circle,
                                          size: 18,
                                          color: AppColors.warning.resolveFrom(
                                            context,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            RouteStrings.stopLine(
                                              _clock(start),
                                              mins,
                                            ),
                                            style: AppTextStyles.callout(
                                              context,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 18),
                    CupertinoButton(
                      minimumSize: const Size.fromHeight(48),
                      onPressed: () => context.pop(),
                      child: Text(
                        RouteStrings.exitPlayback,
                        style: AppTextStyles.body(
                          context,
                          emphasized: true,
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final RouteStats stats;

  static String _dur(Duration d) {
    if (d.inHours >= 1) return '${d.inHours} j ${d.inMinutes % 60} mnt';
    return '${d.inMinutes} mnt';
  }

  @override
  Widget build(BuildContext context) {
    final km = stats.distanceM >= 1000
        ? '${(stats.distanceM / 1000).toStringAsFixed(1)} km'
        : '${stats.distanceM.round()} m';
    final items = [
      (RouteStrings.distance, km),
      (RouteStrings.duration, _dur(stats.duration)),
      (RouteStrings.movingTime, _dur(stats.movingDuration)),
      (
        RouteStrings.avgSpeed,
        '${stats.avgSpeedKmh.round()} ${RouteStrings.kmh}',
      ),
      (
        RouteStrings.maxSpeed,
        '${stats.maxSpeedKmh.round()} ${RouteStrings.kmh}',
      ),
      (RouteStrings.points, '${stats.count}'),
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final (label, value) in items)
          SizedBox(
            width: (MediaQuery.sizeOf(context).width - 32 - 20) / 3,
            child: GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.caption2(
                      context,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: AppTextStyles.callout(context, emphasized: true),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.glassFill.resolveFrom(context),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.glassBorder.resolveFrom(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.tint.resolveFrom(context)),
          const SizedBox(width: 6),
          Text(text, style: AppTextStyles.labelMd(context)),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.big = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final tint = AppColors.tint.resolveFrom(context);
    final size = big ? 56.0 : 44.0;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: big ? tint : AppColors.surfaceHigh.resolveFrom(context),
            border: big
                ? null
                : Border.all(color: AppColors.separator.resolveFrom(context)),
            boxShadow: big && AppColors.isDark(context)
                ? [
                    BoxShadow(
                      color: tint.withValues(alpha: 0.4),
                      blurRadius: 18,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            size: big ? 30 : 22,
            fill: 1,
            color: big
                ? AppColors.onTint.resolveFrom(context)
                : AppColors.textPrimary.resolveFrom(context),
          ),
        ),
      ),
    );
  }
}

class _SpeedPill extends StatelessWidget {
  const _SpeedPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = AppColors.tint.resolveFrom(context);
    return Semantics(
      button: true,
      selected: selected,
      label: '${RouteStrings.speedLabel} $label',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 40, minHeight: 44),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: selected
                    ? tint.withValues(alpha: 0.15)
                    : AppColors.surfaceHigh.resolveFrom(context),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected
                      ? tint
                      : AppColors.separator.resolveFrom(context),
                ),
              ),
              child: Text(
                label,
                style: AppTextStyles.caption1(
                  context,
                  emphasized: selected,
                  color: selected ? AppColors.tint : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.ring});

  final Color color;
  final Color ring;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color,
      border: Border.all(color: ring, width: 2),
    ),
  );
}

class _Cursor extends StatelessWidget {
  const _Cursor({required this.color, required this.ring, required this.glow});

  final Color color;
  final Color ring;
  final bool glow;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color,
      border: Border.all(color: ring, width: 3),
      boxShadow: glow
          ? [BoxShadow(color: color.withValues(alpha: 0.7), blurRadius: 14)]
          : [const BoxShadow(color: Color(0x40000000), blurRadius: 4)],
    ),
  );
}
