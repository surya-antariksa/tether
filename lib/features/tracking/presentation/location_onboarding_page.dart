import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/tracking_providers.dart';
import '../domain/permission_gateway.dart';
import 'tracking_strings.dart';

enum _Step {
  whenInUse,
  always,
  notification,
  battery,
  locationDenied,
  alwaysDenied,
  notificationDenied,
}

/// Layar penjelasan: hanya satu tombol "Lanjut" dan tanpa jalan keluar
/// (docs/08 bagian 7). Layar sesudah dialog (ditolak, panduan baterai) boleh
/// punya dua tombol karena bukan layar penjelasan.
bool _isExplainer(_Step s) =>
    s == _Step.whenInUse || s == _Step.always || s == _Step.notification;

/// Alur izin F13 (docs/07 activity 2.1): lokasi saat dipakai, lokasi selalu,
/// notifikasi, lalu panduan hemat baterai. Penolakan tidak memaksa: aplikasi
/// tetap bisa dipakai dengan mode terbatas.
class LocationOnboardingPage extends ConsumerStatefulWidget {
  const LocationOnboardingPage({super.key});

  @override
  ConsumerState<LocationOnboardingPage> createState() =>
      _LocationOnboardingPageState();
}

class _LocationOnboardingPageState
    extends ConsumerState<LocationOnboardingPage> {
  _Step? _step;
  bool _busy = false;

  PermissionGateway get _gateway => ref.read(permissionGatewayProvider);

  @override
  void initState() {
    super.initState();
    _chooseFirstStep();
  }

  Future<AppPermissionStatus> _status(TrackingPermission p) async {
    try {
      return await _gateway.status(p);
    } catch (_) {
      return AppPermissionStatus.denied;
    }
  }

  Future<AppPermissionStatus> _request(TrackingPermission p) async {
    try {
      return await _gateway.request(p);
    } catch (_) {
      return AppPermissionStatus.denied;
    }
  }

  /// Lewati langkah yang izinnya sudah diberikan (mis. dibuka dari overlay).
  Future<void> _chooseFirstStep() async {
    var step = _Step.whenInUse;
    if ((await _status(TrackingPermission.locationWhenInUse)).isGranted) {
      step = _Step.always;
      if ((await _status(TrackingPermission.locationAlways)).isGranted) {
        step = _Step.notification;
        if ((await _status(TrackingPermission.notification)).isGranted) {
          step = _Step.battery;
        }
      }
    }
    if (mounted) setState(() => _step = step);
  }

  Future<void> _continueFrom(
    TrackingPermission permission,
    _Step onGranted,
    _Step onDenied,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await _request(permission);
    if (permission == TrackingPermission.locationWhenInUse) {
      await ref.read(locationPermissionProvider.notifier).refresh();
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _step = result.isGranted ? onGranted : onDenied;
    });
  }

  void _go(_Step step) => setState(() => _step = step);

  Future<void> _openSettings() async {
    try {
      await _gateway.openSettings();
    } catch (_) {}
  }

  void _finish() {
    ref.read(locationPermissionProvider.notifier).refresh();
    final router = GoRouter.maybeOf(context);
    if (router == null) {
      Navigator.of(context).maybePop();
    } else if (router.canPop()) {
      router.pop();
    } else {
      router.go(AppRoutes.map);
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = _step;
    return PopScope(
      // Layar penjelasan tidak punya jalan keluar, termasuk tombol kembali.
      canPop: step != null && !_isExplainer(step),
      child: CupertinoPageScaffold(
        backgroundColor: AppColors.background,
        child: SafeArea(
          child: step == null
              ? const Center(child: CupertinoActivityIndicator())
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: _buildStep(step),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildStep(_Step step) {
    PrimaryButton primary(String label, VoidCallback onPressed) =>
        PrimaryButton(
          label: label,
          busyLabel: TrackingStrings.processing,
          busy: _busy,
          onPressed: onPressed,
        );
    final settings = _SettingsButton(onPressed: _openSettings);
    return switch (step) {
      _Step.whenInUse => _StepLayout(
        key: ValueKey(step),
        icon: CupertinoIcons.location_fill,
        title: TrackingStrings.whenInUseTitle,
        paragraphs: const [TrackingStrings.reasonWhenInUse],
        points: TrackingStrings.whenInUsePoints,
        actions: [
          primary(
            TrackingStrings.next,
            () => _continueFrom(
              TrackingPermission.locationWhenInUse,
              _Step.always,
              _Step.locationDenied,
            ),
          ),
        ],
      ),
      _Step.always => _StepLayout(
        key: ValueKey(step),
        icon: CupertinoIcons.location_circle_fill,
        title: TrackingStrings.alwaysTitle,
        paragraphs: const [
          TrackingStrings.reasonAlways,
          TrackingStrings.alwaysHint,
        ],
        actions: [
          primary(
            TrackingStrings.next,
            () => _continueFrom(
              TrackingPermission.locationAlways,
              _Step.notification,
              _Step.alwaysDenied,
            ),
          ),
        ],
      ),
      _Step.notification => _StepLayout(
        key: ValueKey(step),
        icon: CupertinoIcons.bell_fill,
        title: TrackingStrings.notificationTitle,
        paragraphs: const [TrackingStrings.reasonNotification],
        actions: [
          primary(
            TrackingStrings.next,
            () => _continueFrom(
              TrackingPermission.notification,
              _Step.battery,
              _Step.notificationDenied,
            ),
          ),
        ],
      ),
      _Step.locationDenied => _StepLayout(
        key: ValueKey(step),
        icon: CupertinoIcons.location_slash_fill,
        title: TrackingStrings.locationDeniedTitle,
        paragraphs: const [TrackingStrings.locationDeniedBody],
        actions: [primary(TrackingStrings.done, _finish), settings],
      ),
      _Step.alwaysDenied => _StepLayout(
        key: ValueKey(step),
        icon: CupertinoIcons.location_slash_fill,
        title: TrackingStrings.alwaysDeniedTitle,
        paragraphs: const [TrackingStrings.alwaysDeniedBody],
        actions: [
          primary(TrackingStrings.next, () => _go(_Step.notification)),
          settings,
        ],
      ),
      _Step.notificationDenied => _StepLayout(
        key: ValueKey(step),
        icon: CupertinoIcons.bell_slash_fill,
        title: TrackingStrings.notificationDeniedTitle,
        paragraphs: const [TrackingStrings.notificationDeniedBody],
        actions: [
          primary(TrackingStrings.next, () => _go(_Step.battery)),
          settings,
        ],
      ),
      _Step.battery => _StepLayout(
        key: ValueKey(step),
        icon: CupertinoIcons.battery_charging,
        title: TrackingStrings.batteryTitle,
        paragraphs: const [TrackingStrings.batteryIntro],
        guides: TrackingStrings.batteryBrands,
        footnote: TrackingStrings.batteryFootnote,
        actions: [primary(TrackingStrings.done, _finish), settings],
      ),
    };
  }
}

/// Kerangka satu langkah: isi bisa digulir (aman pada teks 200%), tombol
/// tetap di bawah.
class _StepLayout extends StatelessWidget {
  const _StepLayout({
    super.key,
    required this.icon,
    required this.title,
    required this.paragraphs,
    required this.actions,
    this.points = const [],
    this.guides = const [],
    this.footnote,
  });

  final IconData icon;
  final String title;
  final List<String> paragraphs;
  final List<String> points;
  final List<BatteryGuide> guides;
  final String? footnote;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Icon(icon, size: 56, color: AppColors.tint),
                ),
                const SizedBox(height: 16),
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: AppTextStyles.title2(context, emphasized: true),
                  ),
                ),
                for (final p in paragraphs) ...[
                  const SizedBox(height: 12),
                  Text(p, style: AppTextStyles.body(context)),
                ],
                if (points.isNotEmpty) const SizedBox(height: 16),
                for (final p in points) _Point(text: p),
                for (final g in guides) ...[
                  const SizedBox(height: 16),
                  Semantics(
                    container: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(g.brand, style: AppTextStyles.headline(context)),
                        const SizedBox(height: 4),
                        Text(
                          g.steps,
                          style: AppTextStyles.subhead(
                            context,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (footnote != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    footnote!,
                    style: AppTextStyles.footnote(
                      context,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: actions,
          ),
        ),
      ],
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ExcludeSemantics(
            child: Icon(
              CupertinoIcons.checkmark_circle_fill,
              size: 20,
              color: AppColors.tint,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AppTextStyles.body(context))),
        ],
      ),
    );
  }
}

class _SettingsButton extends StatelessWidget {
  const _SettingsButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      minimumSize: const Size(44, 44),
      onPressed: onPressed,
      child: Text(
        TrackingStrings.openSettings,
        textAlign: TextAlign.center,
        style: AppTextStyles.body(context, color: AppColors.tint),
      ),
    );
  }
}
