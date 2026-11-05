import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/primary_button.dart';
import '../../auth/data/auth_providers.dart';
import '../data/place_providers.dart';
import '../domain/place.dart';
import '../places_routes.dart';
import 'place_edit_sheet.dart';
import 'place_strings.dart';

/// Halaman daftar dan kelola tempat satu Circle (PRD F7).
class PlacesPage extends ConsumerWidget {
  const PlacesPage({super.key, required this.circleId});

  final String circleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(placesProvider(circleId));
    final places = async.value;
    final full = places != null && places.length >= PlaceLimits.maxPerCircle;
    final canAdd = places != null && !full;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.groupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: const Text(PlaceStrings.title),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(44, 44),
          onPressed: canAdd ? () => _add(context) : null,
          child: const Text(PlaceStrings.add),
        ),
      ),
      child: SafeArea(
        child: places == null
            ? (async.hasError
                  ? _Failed(
                      onRetry: () => ref.invalidate(placesProvider(circleId)),
                    )
                  : const Center(child: CupertinoActivityIndicator()))
            : places.isEmpty
            ? _Empty(onAdd: () => _add(context))
            : _List(circleId: circleId, places: places, full: full),
      ),
    );
  }

  void _add(BuildContext context) =>
      context.push(PlacesRoutes.create(circleId));
}

class _List extends ConsumerWidget {
  const _List({
    required this.circleId,
    required this.places,
    required this.full,
  });

  final String circleId;
  final List<Place> places;
  final bool full;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUserIdProvider);
    final isAdmin = ref.watch(isCircleAdminProvider(circleId)).value ?? false;
    return CustomScrollView(
      slivers: [
        CupertinoSliverRefreshControl(
          onRefresh: () =>
              ref.read(placesProvider(circleId).notifier).refresh(),
        ),
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: CupertinoListSection.insetGrouped(
                header: Semantics(
                  header: true,
                  child: Text(PlaceStrings.count(places.length)),
                ),
                footer: full
                    ? Text(
                        PlaceStrings.limitNote,
                        style: AppTextStyles.footnote(
                          context,
                          color: AppColors.textSecondary,
                        ),
                      )
                    : null,
                children: [
                  for (final p in places)
                    _PlaceRow(
                      place: p,
                      canManage: p.canManage(userId: uid, isAdmin: isAdmin),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({required this.place, required this.canManage});

  final Place place;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    void edit() => showPlaceEditSheet(context, place);
    return Semantics(
      button: canManage,
      label: PlaceStrings.rowLabel(place, canManage: canManage),
      onTap: canManage ? edit : null,
      excludeSemantics: true,
      child: CupertinoListTile.notched(
        leading: Icon(
          CupertinoIcons.placemark_fill,
          color: AppColors.tint.resolveFrom(context),
        ),
        title: Text(place.name, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(PlaceStrings.radiusOf(place.radiusM)),
        trailing: canManage ? const CupertinoListTileChevron() : null,
        onTap: canManage ? edit : null,
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.placemark,
                size: 48,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
              const SizedBox(height: 16),
              Text(
                PlaceStrings.emptyTitle,
                textAlign: TextAlign.center,
                style: AppTextStyles.title2(context, emphasized: true),
              ),
              const SizedBox(height: 8),
              Text(
                PlaceStrings.emptyBody,
                textAlign: TextAlign.center,
                style: AppTextStyles.body(
                  context,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: PlaceStrings.addPlace,
                busyLabel: PlaceStrings.addPlace,
                onPressed: onAdd,
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
              PlaceStrings.loadFailed,
              textAlign: TextAlign.center,
              style: AppTextStyles.body(context),
            ),
            const SizedBox(height: 12),
            CupertinoButton(
              onPressed: onRetry,
              child: const Text(PlaceStrings.retry),
            ),
          ],
        ),
      ),
    );
  }
}
