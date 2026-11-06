import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/selected_circle.dart';
import '../../../core/widgets/primary_button.dart';
import '../../places/data/place_providers.dart';
import '../data/map_providers.dart';
import '../domain/map_circle.dart';
import 'circle_map_view.dart';
import 'map_strings.dart';

/// Tab Peta (F4, F6): peta Circle terpilih + panel anggota.
class MapTabPage extends ConsumerStatefulWidget {
  const MapTabPage({super.key});

  @override
  ConsumerState<MapTabPage> createState() => _MapTabPageState();
}

class _MapTabPageState extends ConsumerState<MapTabPage>
    with WidgetsBindingObserver {
  bool _wasVisible = true;

  /// Id terpilih yang sudah dicoba dicari dengan memuat ulang daftar Circle.
  String? _reloadedFor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Cabang tab yang tidak aktif tetap hidup (indexedStack) tetapi tickernya
    // mati: dipakai sebagai tanda tab kembali terlihat.
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible && !_wasVisible) {
      Future.microtask(() {
        if (mounted) _reload();
      });
    }
    _wasVisible = visible;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _reload();
  }

  /// Muat ulang daftar Circle dan anggota Circle terpilih (tanpa loading).
  void _reload() {
    ref.invalidate(mapCirclesProvider);
    final id = ref.read(selectedCircleIdProvider);
    if (id != null) {
      ref.read(mapMembersProvider(id).notifier).refresh();
      ref.read(placesProvider(id).notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final circlesAsync = ref.watch(mapCirclesProvider);
    final selectedId = ref.watch(selectedCircleIdProvider);
    final circles =
        circlesAsync.value; // data lama dipertahankan saat memuat ulang

    Widget body;
    if (circles == null) {
      body = circlesAsync.hasError
          ? _Failed(onRetry: () => ref.invalidate(mapCirclesProvider))
          : const Center(child: CupertinoActivityIndicator());
    } else if (circles.isEmpty) {
      body = const _NoCircle();
    } else {
      final current = _resolve(circles, selectedId);
      body = current == null
          ? const Center(child: CupertinoActivityIndicator())
          : CircleMapView(
              key: ValueKey(current.id),
              circle: current,
              circles: circles,
              onSelectCircle: (id) =>
                  ref.read(selectedCircleIdProvider.notifier).select(id),
            );
    }
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      child: body,
    );
  }

  /// Circle yang ditampilkan. Bila belum ada pilihan, ambil yang pertama dan
  /// pilih. Bila pilihan tidak ada di daftar (mis. baru dibuat di tab Circle),
  /// muat ulang daftar sekali; bila tetap tidak ada, kembali ke yang pertama.
  MapCircle? _resolve(List<MapCircle> circles, String? selectedId) {
    final match = circles.where((c) => c.id == selectedId).firstOrNull;
    if (match != null) return match;
    if (selectedId != null && _reloadedFor != selectedId) {
      _reloadedFor = selectedId;
      Future.microtask(() {
        if (mounted) ref.invalidate(mapCirclesProvider);
      });
      return circles.first;
    }
    Future.microtask(() {
      if (mounted) {
        ref.read(selectedCircleIdProvider.notifier).select(circles.first.id);
      }
    });
    return circles.first;
  }
}

class _NoCircle extends StatelessWidget {
  const _NoCircle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Symbols.map,
                size: 48,
                color: AppColors.textSecondary.resolveFrom(context),
              ),
              const SizedBox(height: 16),
              Text(
                MapStrings.noCircleTitle,
                textAlign: TextAlign.center,
                style: AppTextStyles.title2(context, emphasized: true),
              ),
              const SizedBox(height: 8),
              Text(
                MapStrings.noCircleBody,
                textAlign: TextAlign.center,
                style: AppTextStyles.body(
                  context,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: MapStrings.openCircleTab,
                busyLabel: MapStrings.openCircleTab,
                onPressed: () => context.go(AppRoutes.circle),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.onRetry});

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
