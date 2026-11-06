import 'package:flutter/cupertino.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/primary_button.dart';
import '../../map/data/map_providers.dart';
import '../../map/presentation/glass.dart';
import '../../map/presentation/members_map.dart'
    show kDefaultCenter, kDefaultZoom, kUserAgentPackageName;
import '../../map/presentation/osm_attribution.dart';
import '../data/place_providers.dart';
import '../domain/place.dart';
import '../domain/place_error.dart';
import '../../map/presentation/map_theme.dart';
import 'place_form.dart';
import 'place_map_layers.dart';
import 'place_strings.dart';

/// Buat tempat: pilih titik dengan mengetuk atau menahan peta, lalu isi nama
/// dan radius. Koordinat tidak pernah ditampilkan, dicatat, atau masuk galat.
class PlacePickerPage extends ConsumerStatefulWidget {
  const PlacePickerPage({
    super.key,
    required this.circleId,
    this.initialCenter,
    this.initialName,
  });

  final String circleId;

  /// Titik awal (mis. dari detail titik riwayat): langsung berpin di sana.
  final LatLng? initialCenter;

  /// Nama awal (mis. saran cepat "Rumah").
  final String? initialName;

  @override
  ConsumerState<PlacePickerPage> createState() => _PlacePickerPageState();
}

class _PlacePickerPageState extends ConsumerState<PlacePickerPage> {
  final _map = MapController();
  final _name = TextEditingController();
  late final MapOptions _options;
  LatLng? _pin;
  int _radius = PlaceLimits.defaultRadiusM;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name.text = widget.initialName ?? '';
    _pin = widget.initialCenter;
    final start = widget.initialCenter ?? _startingPoint();
    _options = MapOptions(
      initialCenter: start ?? kDefaultCenter,
      initialZoom: start == null ? kDefaultZoom : 15,
      minZoom: 2,
      maxZoom: 19,
      interactionOptions: const InteractionOptions(
        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
      ),
      onTap: (_, point) => _setPin(point),
      onLongPress: (_, point) => _setPin(point),
    );
  }

  /// Lokasi diri, lalu anggota lain, lalu tempat yang sudah ada.
  LatLng? _startingPoint() {
    final snap = ref.read(mapMembersProvider(widget.circleId)).value;
    final self = snap?.self?.location?.point;
    if (self != null) return self;
    for (final m in snap?.members ?? const []) {
      final p = m.location?.point;
      if (p != null) return p;
    }
    return ref.read(placesProvider(widget.circleId)).value?.firstOrNull?.center;
  }

  @override
  void dispose() {
    _name.dispose();
    _map.dispose();
    super.dispose();
  }

  void _setPin(LatLng point) {
    if (_saving) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _pin = point;
      _error = null;
    });
  }

  Future<void> _save() async {
    final pin = _pin;
    if (_saving || pin == null) return;
    final issue = validatePlaceName(_name.text);
    if (issue != null) {
      setState(() => _error = PlaceStrings.nameIssue(issue));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(placesProvider(widget.circleId).notifier)
          .create(name: _name.text.trim(), center: pin, radiusM: _radius);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = PlaceStrings.error(
            e is PlaceError ? e.kind : PlaceErrorKind.unknown,
          );
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing =
        ref.watch(placesProvider(widget.circleId)).value ?? const <Place>[];
    final pin = _pin;
    final tint = AppColors.tint.resolveFrom(context);
    final tiles = ref.watch(mapTileProviderProvider);
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: const CupertinoNavigationBar(
        middle: Text(PlaceStrings.pickTitle),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  FlutterMap(
                    mapController: _map,
                    options: _options,
                    children: [
                      ThemedTileLayer(
                        userAgentPackageName: kUserAgentPackageName,
                        tileProvider: tiles,
                      ),
                      PlaceCirclesLayer(places: existing),
                      PlaceLabelsLayer(places: existing),
                      if (pin != null) ...[
                        CircleLayer(
                          circles: [
                            CircleMarker(
                              point: pin,
                              radius: _radius.toDouble(),
                              useRadiusInMeter: true,
                              color: tint.withValues(alpha: 0.25),
                              borderColor: tint,
                              borderStrokeWidth: 3,
                            ),
                          ],
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: pin,
                              width: 44,
                              height: 44,
                              alignment: Alignment.topCenter,
                              child: IgnorePointer(
                                child: Semantics(
                                  label: PlaceStrings.draftPinLabel,
                                  excludeSemantics: true,
                                  child: Icon(
                                    Symbols.near_me,
                                    size: 40,
                                    color: tint,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  const Positioned(left: 8, bottom: 4, child: OsmAttribution()),
                  Positioned(
                    top: 12,
                    right: 16,
                    child: GlassIconButton(
                      icon: Symbols.gps_fixed,
                      label: PlaceStrings.useMapCenter,
                      onPressed: _saving
                          ? null
                          : () => _setPin(_map.camera.center),
                    ),
                  ),
                ],
              ),
            ),
            _Panel(
              child: pin == null
                  ? Text(
                      PlaceStrings.pickHint,
                      style: AppTextStyles.body(
                        context,
                        color: AppColors.textSecondary,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PlaceForm(
                          controller: _name,
                          radiusM: _radius,
                          enabled: !_saving,
                          error: _error,
                          onRadiusChanged: (r) => setState(() => _radius = r),
                          onNameChanged: () {
                            if (_error != null) setState(() => _error = null);
                          },
                          onSubmitted: _save,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          PlaceStrings.movePinHint,
                          style: AppTextStyles.footnote(
                            context,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        PrimaryButton(
                          label: PlaceStrings.save,
                          busyLabel: PlaceStrings.saving,
                          busy: _saving,
                          onPressed: _save,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background.resolveFrom(context),
        border: Border(
          top: BorderSide(
            color: AppColors.separator.resolveFrom(context),
            width: 0.5,
          ),
        ),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.55),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + media.padding.bottom),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
