import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../activity/data/activity_providers.dart';
import '../../places/data/place_providers.dart';
import '../../places/domain/place.dart';
import '../../places/places_routes.dart';
import '../../places/presentation/place_strings.dart';
import '../../safety/presentation/safety_sheet.dart';
import '../../tracking/presentation/tracking_overlay.dart';
import '../data/map_providers.dart';
import '../data/map_style_provider.dart';
import '../domain/map_circle.dart';
import '../domain/map_member.dart';
import '../domain/map_repository.dart';
import '../domain/presence.dart';
import '../domain/vehicle_type.dart';
import 'glass.dart';
import 'map_strings.dart';
import 'map_type_sheet.dart';
import 'members_map.dart';
import 'members_sheet.dart';
import 'osm_attribution.dart';
import 'pause_sheet.dart';
import 'relative_time.dart';

/// Peta penuh layar untuk satu Circle: marker anggota, judul, kontrol melayang,
/// indikator realtime, dan panel anggota nonmodal.
class CircleMapView extends ConsumerStatefulWidget {
  const CircleMapView({
    super.key,
    required this.circle,
    required this.circles,
    required this.onSelectCircle,
  });

  final MapCircle circle;
  final List<MapCircle> circles;
  final ValueChanged<String> onSelectCircle;

  @override
  ConsumerState<CircleMapView> createState() => _CircleMapViewState();
}

class _CircleMapViewState extends ConsumerState<CircleMapView>
    with SingleTickerProviderStateMixin {
  final _map = MapController();
  final _sheet = DraggableScrollableController();
  final _extent = ValueNotifier<double>(kSheetMedium);
  // Dibuat di initState, bukan lazy: dispose() yang menyentuh field lazy
  // membuat Ticker pada elemen yang sudah tidak aktif (assertion di debug).
  late final AnimationController _cam;
  VoidCallback? _camTick;
  bool _busy = false;

  /// Fokus dari tab Aktivitas yang belum bisa diterapkan karena FlutterMap
  /// belum terpasang (anggota Circle masih dimuat). Diterapkan begitu peta
  /// dibangun.
  LatLng? _pendingFocus;

  @override
  void initState() {
    super.initState();
    _cam = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    // Fokus yang sudah diminta sebelum peta ini terpasang (dari tab Aktivitas).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _applyActivityFocus(ref.read(activityMapFocusProvider));
    });
  }

  @override
  void dispose() {
    _cam.dispose();
    _extent.dispose();
    _sheet.dispose();
    _map.dispose();
    super.dispose();
  }

  /// Pusatkan kamera pada lokasi SOS yang dibuka dari tab Aktivitas.
  void _applyActivityFocus(ActivityMapFocus? f) {
    if (f == null || f.circleId != widget.circle.id) return;
    _pendingFocus = LatLng(f.lat, f.lng);
    ref.read(activityMapFocusProvider.notifier).clear();
    _flushPendingFocus();
  }

  /// Menerapkan fokus tertunda bila peta sudah terpasang; bila belum
  /// (controller melempar), dicoba lagi saat peta dibangun.
  void _flushPendingFocus() {
    final target = _pendingFocus;
    if (target == null) return;
    try {
      _focus(target);
      _pendingFocus = null;
    } catch (_) {
      // FlutterMap belum dirender; _content menjadwalkan percobaan berikutnya.
    }
  }

  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  // ---- Kamera ----

  void _animateTo(LatLng center, double zoom) {
    if (_reduceMotion) {
      _map.move(center, zoom);
      return;
    }
    final from = _map.camera;
    final centerTween = LatLngTween(begin: from.center, end: center);
    final zoomTween = Tween<double>(begin: from.zoom, end: zoom);
    if (_camTick != null) _cam.removeListener(_camTick!);
    _camTick = () {
      final t = Curves.easeInOut.transform(_cam.value);
      _map.move(centerTween.lerp(t), zoomTween.transform(t));
    };
    _cam.addListener(_camTick!);
    _cam.forward(from: 0);
  }

  /// Tinggi panel yang menutup peta (dibatasi sampai posisi sedang agar peta
  /// tetap terlihat saat kamera dipusatkan).
  double get _coveredPx =>
      math.min(_extent.value, kSheetMedium) * MediaQuery.sizeOf(context).height;

  void _fitAll(List<MarkerEntry> entries) {
    if (entries.isEmpty) return;
    final top = MediaQuery.paddingOf(context).top + 96;
    final fit = CameraFit.coordinates(
      coordinates: [for (final e in entries) e.point],
      padding: EdgeInsets.fromLTRB(48, top, 64, _coveredPx + 32),
      maxZoom: 16,
    ).fit(_map.camera);
    _animateTo(fit.center, fit.zoom);
  }

  /// Pusatkan [point] di area peta yang tidak tertutup panel.
  void _focus(LatLng point) {
    final zoom = math.max(_map.camera.zoom, 15.0);
    final px = _map.camera.projectAtZoom(point, zoom);
    final center = _map.camera.unprojectAtZoom(
      px + Offset(0, _coveredPx / 2),
      zoom,
    );
    if (_sheet.isAttached && _extent.value > kSheetMedium) {
      if (_reduceMotion) {
        _sheet.jumpTo(kSheetMedium);
      } else {
        _sheet.animateTo(
          kSheetMedium,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
        );
      }
    }
    _animateTo(center, zoom);
  }

  // ---- Jeda berbagi ----

  Future<void> _pause() async {
    final choice = await showPauseSheet(context);
    if (choice == null || !mounted) return;
    await _run(
      () => ref
          .read(mapMembersProvider(widget.circle.id).notifier)
          .pause(minutes: choice.minutes),
      MapStrings.pauseFailedTitle,
    );
  }

  Future<void> _resume() => _run(
    () => ref.read(mapMembersProvider(widget.circle.id).notifier).resume(),
    MapStrings.resumeFailedTitle,
  );

  Future<void> _run(Future<void> Function() action, String errorTitle) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      final kind = e is MapFailure ? e.kind : MapFailureKind.unknown;
      await showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: Text(errorTitle),
          content: Text(MapStrings.failure(kind)),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(MapStrings.close),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickCircle() async {
    final id = await showCirclePicker(
      context,
      circles: [for (final c in widget.circles) (id: c.id, name: c.name)],
      currentId: widget.circle.id,
    );
    if (id != null && id != widget.circle.id) widget.onSelectCircle(id);
  }

  // ---- Bangun tampilan ----

  List<MarkerEntry> _entries(MapSnapshot snap, DateTime now) {
    final entries = <MarkerEntry>[];
    for (final m in snap.members) {
      final presence = presenceOf(m, now);
      final loc = m.location;
      if (!hasMarker(presence) || loc == null) continue;
      final isSelf = m.userId == snap.selfId;
      final ago = formatRelativeTime(loc.lastSeenAt, now);
      final isActive = presence == PresenceState.active;
      entries.add(
        MarkerEntry(
          userId: m.userId,
          name: m.displayName,
          colorHex: m.colorHex,
          point: loc.point,
          presence: presence,
          isSelf: isSelf,
          isMoving: isActive ? loc.isMoving : null,
          vehicle: isActive ? loc.vehicle : VehicleType.none,
          speedKmh: isActive ? loc.speedKmh : null,
          semanticLabel: MapStrings.memberLabel(
            m.displayName,
            isSelf: isSelf,
            status: MapStrings.statusText(
              presence,
              isMoving: loc.isMoving,
              ago: ago,
            ),
            updated: isActive ? MapStrings.updated(ago) : null,
          ),
        ),
      );
    }
    // Diri sendiri digambar paling atas.
    entries.sort((a, b) => (a.isSelf ? 1 : 0).compareTo(b.isSelf ? 1 : 0));
    return entries;
  }

  Future<void> _pickMapType() async {
    final current = ref.read(mapStyleProvider);
    final picked = await showMapTypeSheet(context, current);
    if (picked != null) {
      await ref.read(mapStyleProvider.notifier).select(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.circle.id;
    ref.listen(activityMapFocusProvider, (_, f) => _applyActivityFocus(f));
    final async = ref.watch(mapMembersProvider(id));
    final now = ref.watch(mapClockProvider);
    return async.when(
      skipLoadingOnReload: true,
      loading: () => const Center(child: CupertinoActivityIndicator()),
      error: (_, _) =>
          _LoadFailed(onRetry: () => ref.invalidate(mapMembersProvider(id))),
      data: (snap) => _content(context, snap, now),
    );
  }

  Widget _content(BuildContext context, MapSnapshot snap, DateTime now) {
    if (_pendingFocus != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _flushPendingFocus();
      });
    }
    final entries = _entries(snap, now);
    final media = MediaQuery.of(context);
    final selfEntry = entries.where((e) => e.isSelf).firstOrNull;
    final canSwitch = widget.circles.length > 1;
    final tileProvider = ref.watch(mapTileProviderProvider);
    // Galat memuat tempat tidak boleh mengganggu peta: pakai data terakhir.
    final places =
        ref.watch(placesProvider(widget.circle.id)).value ?? const <Place>[];
    return Stack(
      fit: StackFit.expand,
      children: [
        MembersMap(
          key: ValueKey(widget.circle.id),
          controller: _map,
          entries: entries,
          tileProvider: tileProvider,
          places: places,
          initialPadding: EdgeInsets.fromLTRB(
            48,
            media.padding.top + 96,
            64,
            kSheetMedium * media.size.height + 32,
          ),
          onMarkerTap: (userId) {
            final e = entries.where((e) => e.userId == userId).firstOrNull;
            if (e != null) _focus(e.point);
          },
        ),
        ValueListenableBuilder<double>(
          valueListenable: _extent,
          builder: (context, extent, child) => Positioned(
            left: 8,
            bottom: extent * media.size.height + 4,
            child: child!,
          ),
          child: const OsmAttribution(),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _TitlePill(
                            name: widget.circle.name,
                            canSwitch: canSwitch,
                            onTap: canSwitch ? _pickCircle : null,
                          ),
                          const SizedBox(height: 8),
                          const TrackingOverlay(),
                          if (!snap.realtimeConnected) ...[
                            const SizedBox(height: 8),
                            const _OfflineChip(),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    children: [
                      GlassIconButton(
                        icon: Symbols.crop_free,
                        label: MapStrings.centerAll,
                        onPressed: entries.isEmpty
                            ? null
                            : () => _fitAll(entries),
                      ),
                      const SizedBox(height: 8),
                      GlassIconButton(
                        icon: Symbols.near_me,
                        label: MapStrings.centerMe,
                        onPressed: selfEntry == null
                            ? null
                            : () => _focus(selfEntry.point),
                      ),
                      const SizedBox(height: 8),
                      GlassIconButton(
                        icon: Symbols.location_on,
                        label: PlaceStrings.openFromMap,
                        onPressed: () =>
                            context.push(PlacesRoutes.list(widget.circle.id)),
                      ),
                      const SizedBox(height: 8),
                      GlassIconButton(
                        icon: Symbols.layers,
                        label: MapStrings.mapTypeLabel,
                        onPressed: _pickMapType,
                      ),
                      const SizedBox(height: 8),
                      SafetyActionsButton(circleId: widget.circle.id),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        NotificationListener<DraggableScrollableNotification>(
          onNotification: (n) {
            _extent.value = n.extent;
            return false;
          },
          child: MembersSheet(
            controller: _sheet,
            circleName: widget.circle.name,
            members: snap.members,
            selfId: snap.selfId,
            now: now,
            busy: _busy,
            onMemberTap: (MapMember m) {
              final loc = m.location;
              if (loc != null) _focus(loc.point);
            },
            onPause: _pause,
            onResume: _resume,
          ),
        ),
      ],
    );
  }
}

class _TitlePill extends StatelessWidget {
  const _TitlePill({
    required this.name,
    required this.canSwitch,
    required this.onTap,
  });

  final String name;
  final bool canSwitch;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      button: canSwitch,
      label: MapStrings.circleTitleLabel(name, canSwitch: canSwitch),
      onTap: onTap,
      excludeSemantics: true,
      child: GlassSurface(
        child: CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          minimumSize: const Size(44, 44),
          onPressed: onTap,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.success.resolveFrom(context),
                  boxShadow: AppColors.isDark(context)
                      ? [
                          BoxShadow(
                            color: AppColors.success
                                .resolveFrom(context)
                                .withValues(alpha: 0.8),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.headline(context),
                ),
              ),
              if (canSwitch) ...[
                const SizedBox(width: 4),
                Icon(
                  Symbols.expand_more,
                  size: 18,
                  color: AppColors.textSecondary.resolveFrom(context),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Indikator kecil bahwa koneksi realtime terputus (tidak mengganggu).
class _OfflineChip extends StatelessWidget {
  const _OfflineChip();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: MapStrings.realtimeOfflineLabel,
      excludeSemantics: true,
      child: GlassSurface(
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Symbols.wifi_off,
                size: 14,
                color: AppColors.textPrimary.resolveFrom(context),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  MapStrings.realtimeOffline,
                  style: AppTextStyles.footnote(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              MapStrings.loadFailed,
              textAlign: TextAlign.center,
              style: AppTextStyles.body(context),
            ),
            const SizedBox(height: 12),
            CupertinoButton(
              onPressed: onRetry,
              child: const Text(MapStrings.retry),
            ),
          ],
        ),
      ),
    );
  }
}
