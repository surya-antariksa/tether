import 'package:flutter/cupertino.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../places/domain/place.dart';
import '../../places/presentation/place_map_layers.dart';
import '../domain/presence.dart';
import 'member_marker.dart';

/// Pusat awal bila belum ada anggota yang punya marker (Jakarta).
const LatLng kDefaultCenter = LatLng(-6.2088, 106.8456);
const double kDefaultZoom = 11;

/// Syarat kebijakan tile OSM: tile dari tile.openstreetmap.org dan
/// User-Agent yang mengenali aplikasi.
const String kTileUrlTemplate =
    'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const String kUserAgentPackageName = 'id.tether.tether';

/// Satu marker di peta.
class MarkerEntry {
  const MarkerEntry({
    required this.userId,
    required this.name,
    required this.colorHex,
    required this.point,
    required this.presence,
    required this.isSelf,
    required this.isMoving,
    required this.semanticLabel,
  });

  final String userId;
  final String name;
  final String colorHex;
  final LatLng point;
  final PresenceState presence;
  final bool isSelf;
  final bool? isMoving;
  final String semanticLabel;
}

/// Peta flutter_map dengan marker anggota. Marker berpindah halus bila titik
/// berubah (dilewati bila Reduce Motion aktif).
class MembersMap extends StatefulWidget {
  const MembersMap({
    super.key,
    required this.controller,
    required this.entries,
    required this.tileProvider,
    required this.initialPadding,
    required this.onMarkerTap,
    this.places = const [],
  });

  final MapController controller;
  final List<MarkerEntry> entries;
  final TileProvider tileProvider;

  /// Padding fit-bounds awal (menghindari panel dan tombol).
  final EdgeInsets initialPadding;
  final ValueChanged<String> onMarkerTap;

  /// Tempat Circle: lingkaran radius dan nama, di bawah marker anggota.
  final List<Place> places;

  @override
  State<MembersMap> createState() => _MembersMapState();
}

class _MembersMapState extends State<MembersMap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
    value: 1,
  );
  Map<String, LatLng> _from = {};
  Map<String, LatLng> _to = {};

  late final MapOptions _options = MapOptions(
    initialCenter: kDefaultCenter,
    initialZoom: kDefaultZoom,
    initialCameraFit: widget.entries.isEmpty
        ? null
        : CameraFit.coordinates(
            coordinates: [for (final e in widget.entries) e.point],
            padding: widget.initialPadding,
            maxZoom: 16,
          ),
    minZoom: 2,
    maxZoom: 19,
    interactionOptions: const InteractionOptions(
      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
    ),
  );

  @override
  void initState() {
    super.initState();
    _to = _targets(widget.entries);
  }

  static Map<String, LatLng> _targets(List<MarkerEntry> es) => {
    for (final e in es) e.userId: e.point,
  };

  LatLng _current(String id) {
    final to = _to[id]!;
    final from = _from[id];
    if (from == null) return to;
    return LatLngTween(
      begin: from,
      end: to,
    ).lerp(Curves.easeInOut.transform(_anim.value));
  }

  @override
  void didUpdateWidget(MembersMap old) {
    super.didUpdateWidget(old);
    final next = _targets(widget.entries);
    var changed = next.length != _to.length;
    for (final e in next.entries) {
      if (_to[e.key] != e.value) changed = true;
    }
    if (!changed) return;
    // Mulai dari posisi yang sedang tampil supaya tidak melompat.
    _from = {
      for (final id in next.keys)
        if (_to.containsKey(id)) id: _current(id),
    };
    _to = next;
    if (MediaQuery.disableAnimationsOf(context)) {
      _anim.value = 1;
    } else {
      _anim.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: widget.controller,
      options: _options,
      children: [
        TileLayer(
          urlTemplate: kTileUrlTemplate,
          userAgentPackageName: kUserAgentPackageName,
          tileProvider: widget.tileProvider,
          maxNativeZoom: 19,
        ),
        PlaceCirclesLayer(places: widget.places),
        PlaceLabelsLayer(places: widget.places),
        AnimatedBuilder(
          animation: _anim,
          builder: (context, _) => MarkerLayer(
            markers: [
              for (final e in widget.entries)
                Marker(
                  point: _current(e.userId),
                  width: kMarkerBox,
                  height: kMarkerBox,
                  child: MemberMarker(
                    name: e.name,
                    colorHex: e.colorHex,
                    presence: e.presence,
                    isSelf: e.isSelf,
                    isMoving: e.isMoving,
                    semanticLabel: e.semanticLabel,
                    onTap: () => widget.onMarkerTap(e.userId),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
