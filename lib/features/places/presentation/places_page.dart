import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/design_widgets.dart';
import '../../../core/widgets/glass_card.dart';
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
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AppColors.tint
                    .resolveFrom(context)
                    .withValues(alpha: canAdd ? 0.5 : 0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Symbols.add,
                  size: 16,
                  color: AppColors.tint.resolveFrom(context),
                ),
                const SizedBox(width: 4),
                Text(
                  PlaceStrings.add,
                  style: AppTextStyles.labelMd(context, color: AppColors.tint),
                ),
              ],
            ),
          ),
        ),
      ),
      child: AtmosphereBackground(
        child: SafeArea(
          child: places == null
              ? (async.hasError
                    ? _Failed(
                        onRetry: () => ref.invalidate(placesProvider(circleId)),
                      )
                    : const Center(child: CupertinoActivityIndicator()))
              : places.isEmpty
              ? _Empty(onAdd: (name) => _add(context, name: name))
              : _List(circleId: circleId, places: places, full: full),
        ),
      ),
    );
  }

  void _add(BuildContext context, {String? name}) =>
      context.push(PlacesRoutes.create(circleId, name: name));
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
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SectionLabel(PlaceStrings.count(places.length)),
                    ),
                    for (final p in places) ...[
                      _PlaceRow(
                        place: p,
                        canManage: p.canManage(userId: uid, isAdmin: isAdmin),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (full)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          PlaceStrings.limitNote,
                          style: AppTextStyles.footnote(
                            context,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
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
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: canManage ? edit : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: GlassCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const IconTile(
                  icon: Symbols.location_on,
                  color: AppColors.tint,
                  size: 40,
                  iconSize: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body(context, emphasized: true),
                      ),
                      Text(
                        PlaceStrings.radiusOf(place.radiusM),
                        style: AppTextStyles.footnote(
                          context,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (canManage)
                  Icon(
                    Symbols.chevron_right,
                    size: 20,
                    color: AppColors.textSecondary.resolveFrom(context),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onAdd});

  /// Dipanggil dengan nama awal (saran cepat) atau null (tambah biasa).
  final void Function(String? name) onAdd;

  @override
  Widget build(BuildContext context) {
    final tint = AppColors.tint.resolveFrom(context);
    final suggestions = [
      (PlaceStrings.suggestHome, PlaceStrings.suggestHomeHint, Symbols.home),
      (
        PlaceStrings.suggestSchool,
        PlaceStrings.suggestSchoolHint,
        Symbols.school,
      ),
      (PlaceStrings.suggestFav, PlaceStrings.suggestFavHint, Symbols.star),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 96),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            children: [
              Container(
                width: 128,
                height: 128,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: tint.withValues(alpha: 0.25)),
                ),
                child: Container(
                  width: 100,
                  height: 100,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: tint.withValues(alpha: 0.4)),
                  ),
                  child: const IconTile(
                    icon: Symbols.location_on,
                    color: AppColors.tint,
                    size: 64,
                    iconSize: 32,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const StatusBadge(
                text: PlaceStrings.savedCountZero,
                dotColor: AppColors.tint,
              ),
              const SizedBox(height: 20),
              Semantics(
                header: true,
                child: Text(
                  PlaceStrings.emptyTitle,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.title1(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                PlaceStrings.emptyBody,
                textAlign: TextAlign.center,
                style: AppTextStyles.callout(
                  context,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: PlaceStrings.addPlace,
                busyLabel: PlaceStrings.addPlace,
                onPressed: () => onAdd(null),
              ),
              const SizedBox(height: 32),
              Align(
                alignment: Alignment.centerLeft,
                child: SectionLabel(
                  PlaceStrings.quickSuggestions,
                  trailing: Text(
                    PlaceStrings.tapToSet,
                    style: AppTextStyles.caption2(
                      context,
                      emphasized: true,
                      color: AppColors.tint,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (var i = 0; i < suggestions.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(
                      child: Semantics(
                        button: true,
                        label: '${suggestions[i].$1}, ${suggestions[i].$2}',
                        excludeSemantics: true,
                        onTap: () => onAdd(suggestions[i].$1),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onAdd(suggestions[i].$1),
                          child: GlassCard(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 14,
                            ),
                            child: Column(
                              children: [
                                Icon(suggestions[i].$3, size: 22, color: tint),
                                const SizedBox(height: 8),
                                Text(
                                  suggestions[i].$1,
                                  style: AppTextStyles.callout(
                                    context,
                                    emphasized: true,
                                  ),
                                ),
                                Text(
                                  suggestions[i].$2,
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.caption2(
                                    context,
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              GlassCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Symbols.verified_user,
                      size: 16,
                      color: AppColors.success.resolveFrom(context),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        PlaceStrings.geofenceNote,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.caption1(
                          context,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
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
