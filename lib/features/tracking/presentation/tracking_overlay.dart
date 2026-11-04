import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/tracking_providers.dart';
import '../data/tracking_service.dart';
import '../domain/tracking_status.dart';
import '../tracking_routes.dart';
import 'tracking_strings.dart';

/// Pil status pelacakan di atas peta: titik berwarna ditambah teks (tidak
/// hanya warna). Ukurannya mengikuti isi; pemasang menempatkannya (mis.
/// Positioned atau Align) dan mengurus safe area. Mengetuk membuka sheet
/// detail, kecuali "Perlu izin lokasi" yang membuka onboarding izin.
class TrackingOverlay extends ConsumerStatefulWidget {
  const TrackingOverlay({super.key});

  @override
  ConsumerState<TrackingOverlay> createState() => _TrackingOverlayState();
}

class _TrackingOverlayState extends ConsumerState<TrackingOverlay>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Pengguna mungkin mengubah izin di pengaturan sistem lalu kembali.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(locationPermissionProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(trackingServiceProvider);
    final status = snapshot.status;
    final text = overlayText(snapshot);
    final needsPermission = status == TrackingStatus.needsPermission;
    return Semantics(
      button: true,
      label: text,
      hint: needsPermission
          ? TrackingStrings.hintOpenPermission
          : TrackingStrings.hintOpenDetail,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (needsPermission) {
            context.push(locationOnboardingPath);
          } else {
            showTrackingDetailSheet(context);
          }
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, maxWidth: 360),
          child: _GlassPill(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StatusDot(color: statusColor(status)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    text,
                    style: AppTextStyles.subhead(context, emphasized: true),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Teks pil untuk [snapshot].
String overlayText(TrackingSnapshot snapshot) => switch (snapshot.status) {
  TrackingStatus.running => TrackingStrings.overlayRunning,
  TrackingStatus.needsPermission => TrackingStrings.overlayNeedsPermission,
  TrackingStatus.needsCircle => TrackingStrings.overlayNeedsCircle,
  TrackingStatus.offlineWithQueue => TrackingStrings.overlayOffline(
    snapshot.queued,
  ),
  TrackingStatus.unavailable => TrackingStrings.overlayUnavailable,
  TrackingStatus.error => TrackingStrings.overlayError,
  TrackingStatus.idle => TrackingStrings.overlayIdle,
};

Color statusColor(TrackingStatus status) => switch (status) {
  TrackingStatus.running => AppColors.success,
  TrackingStatus.needsPermission ||
  TrackingStatus.needsCircle ||
  TrackingStatus.offlineWithQueue => AppColors.warning,
  TrackingStatus.error => AppColors.danger,
  TrackingStatus.unavailable || TrackingStatus.idle => AppColors.textSecondary,
};

/// Kaca ringan: blur tipis ditambah tint. Kontras tinggi memakai permukaan
/// solid (docs/08 bagian 2: efek kaca hanya hiasan, bukan syarat baca).
class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = CupertinoDynamicColor.resolve(AppColors.background, context);
    final solid = MediaQuery.maybeHighContrastOf(context) ?? false;
    final content = DecoratedBox(
      decoration: BoxDecoration(
        color: solid ? base : base.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: CupertinoDynamicColor.resolve(AppColors.separator, context),
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: child,
      ),
    );
    if (solid) return content;
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: content,
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: CupertinoDynamicColor.resolve(color, context),
        shape: BoxShape.circle,
      ),
    ),
  );
}

/// Sheet detail ringkas. Hanya di build debug atau SIMULATE_LOCATION, memuat
/// tombol simulasi.
Future<void> showTrackingDetailSheet(BuildContext context) =>
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => const _DetailSheet(),
    );

class _DetailSheet extends ConsumerWidget {
  const _DetailSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(trackingServiceProvider);
    final allowSim = ref.watch(simulationAllowedProvider);
    final simActive = ref.watch(simulationActiveProvider);
    final dropped = s.dropped + s.droppedInvalid;
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: CupertinoDynamicColor.resolve(
              AppColors.groupedBackground,
              context,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.85,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: DefaultTextStyle(
                  style: AppTextStyles.body(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 5,
                          decoration: BoxDecoration(
                            color: CupertinoDynamicColor.resolve(
                              CupertinoColors.systemGrey3,
                              context,
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Semantics(
                        header: true,
                        child: Text(
                          TrackingStrings.sheetTitle,
                          style: AppTextStyles.title3(
                            context,
                            emphasized: true,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        statusExplanation(s),
                        style: AppTextStyles.body(
                          context,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _Rows(
                        rows: [
                          (TrackingStrings.sent, '${s.sent}'),
                          (TrackingStrings.queued, '${s.queued}'),
                          (TrackingStrings.dropped, '$dropped'),
                          (TrackingStrings.skipped, '${s.skippedByServer}'),
                          (
                            TrackingStrings.lastError,
                            s.lastError ?? TrackingStrings.none,
                          ),
                        ],
                      ),
                      if (allowSim) ...[
                        const SizedBox(height: 24),
                        Semantics(
                          header: true,
                          child: Text(
                            TrackingStrings.simulationTitle,
                            style: AppTextStyles.headline(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          TrackingStrings.simulationNote,
                          style: AppTextStyles.subhead(
                            context,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        PrimaryButton(
                          label: simActive
                              ? TrackingStrings.simulationStop
                              : TrackingStrings.simulationStart,
                          busyLabel: TrackingStrings.processing,
                          onPressed: () {
                            final n = ref.read(
                              simulationActiveProvider.notifier,
                            );
                            simActive ? n.stop() : n.start();
                          },
                        ),
                      ],
                      const SizedBox(height: 8),
                      CupertinoButton(
                        minimumSize: const Size(44, 44),
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          TrackingStrings.close,
                          style: AppTextStyles.body(
                            context,
                            color: AppColors.tint,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Penjelasan satu kalimat di sheet. Memakai [TrackingSnapshot.detail] untuk
/// galat sumber lokasi (sudah bebas koordinat).
String statusExplanation(TrackingSnapshot s) => switch (s.status) {
  TrackingStatus.idle => TrackingStrings.sheetIdle,
  TrackingStatus.needsPermission => TrackingStrings.sheetNeedsPermission,
  TrackingStatus.needsCircle => TrackingStrings.sheetNeedsCircle,
  TrackingStatus.unavailable => TrackingStrings.sheetUnavailable,
  TrackingStatus.running => TrackingStrings.sheetRunning,
  TrackingStatus.offlineWithQueue => TrackingStrings.sheetOffline,
  TrackingStatus.error => s.detail ?? TrackingStrings.sheetErrorFallback,
};

class _Rows extends StatelessWidget {
  const _Rows({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CupertinoDynamicColor.resolve(
          AppColors.groupedItemBackground,
          context,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (final (label, value) in rows)
            Semantics(
              container: true,
              label: '$label: $value',
              excludeSemantics: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(label, style: AppTextStyles.body(context)),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        value,
                        textAlign: TextAlign.end,
                        style: AppTextStyles.body(
                          context,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
