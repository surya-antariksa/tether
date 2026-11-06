import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/selected_circle.dart';
import '../../circle/data/circle_providers.dart';
import '../data/profile_providers.dart';
import '../domain/notification_settings.dart';
import 'profile_strings.dart';

/// Pengaturan notifikasi: tiga sakelar (notification_settings), metode pengiriman,
/// dan protokol keselamatan inti SOS (selalu aktif).
class NotificationSettingsPage extends ConsumerWidget {
  const NotificationSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(notificationSettingsProvider);
    return CupertinoPageScaffold(
      backgroundColor: AppColors.groupedBackground,
      navigationBar: const CupertinoNavigationBar(
        middle: Text(ProfileStrings.notificationTitle),
      ),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: settings.when(
              data: (s) => _Content(settings: s),
              loading: () => const Center(child: CupertinoActivityIndicator()),
              error: (_, _) => _LoadFailed(
                onRetry: () => ref.invalidate(notificationSettingsProvider),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.settings});

  final NotificationSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final circles = ref.watch(myCirclesProvider).value;
    final selectedId = ref.watch(selectedCircleIdProvider);
    String circleName = 'Circle Keluarga';
    if (circles != null && circles.isNotEmpty) {
      final cur = circles.where((c) => c.id == selectedId);
      circleName = cur.isNotEmpty ? cur.first.name : circles.first.name;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // Breadcrumb & Privacy Badge
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.success.resolveFrom(context),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.success
                                .resolveFrom(context)
                                .withValues(alpha: 0.67),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Circle: $circleName',
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption1(
                          context,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: CupertinoDynamicColor.resolve(
                    AppColors.groupedItemBackground,
                    context,
                  ),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: CupertinoDynamicColor.resolve(
                      AppColors.separator,
                      context,
                    ),
                    width: 0.6,
                  ),
                ),
                child: Text(
                  'Privasi Aktif',
                  style: AppTextStyles.caption2(
                    context,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Bento Card 1: Tiba dan pergi
        _BentoSwitchCard(
          icon: Symbols.near_me,
          iconColor: AppColors.tint.resolveFrom(context),
          iconBgColor: AppColors.tint
              .resolveFrom(context)
              .withValues(alpha: 0.13),
          label: ProfileStrings.notifArriveLeave,
          hint: ProfileStrings.notifArriveLeaveHint,
          value: settings.arriveLeave,
          onChanged: (v) =>
              _set(context, ref, (cur) => cur.copyWith(arriveLeave: v)),
        ),

        // Bento Card 2: Check-in
        _BentoSwitchCard(
          icon: Symbols.check_circle,
          iconColor: AppColors.success.resolveFrom(context),
          iconBgColor: AppColors.success
              .resolveFrom(context)
              .withValues(alpha: 0.13),
          label: ProfileStrings.notifCheckin,
          hint: ProfileStrings.notifCheckinHint,
          value: settings.checkin,
          onChanged: (v) =>
              _set(context, ref, (cur) => cur.copyWith(checkin: v)),
        ),

        // Bento Card 3: Perubahan anggota
        _BentoSwitchCard(
          icon: Symbols.group,
          iconColor: AppColors.tint.resolveFrom(context),
          iconBgColor: AppColors.tint
              .resolveFrom(context)
              .withValues(alpha: 0.13),
          label: ProfileStrings.notifMemberChanges,
          hint: ProfileStrings.notifMemberChangesHint,
          value: settings.memberChanges,
          onChanged: (v) =>
              _set(context, ref, (cur) => cur.copyWith(memberChanges: v)),
        ),

        const SizedBox(height: 10),

        // Delivery Channels Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CupertinoDynamicColor.resolve(
              AppColors.groupedItemBackground,
              context,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: CupertinoDynamicColor.resolve(
                AppColors.separator,
                context,
              ).withValues(alpha: 0.4),
              width: 0.8,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Symbols.tune,
                          size: 16,
                          color: AppColors.textSecondary.resolveFrom(context),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Metode Pengiriman',
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.subhead(
                              context,
                              emphasized: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Semua Aktif',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.tint.resolveFrom(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: CupertinoDynamicColor.resolve(
                          AppColors.groupedBackground,
                          context,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: CupertinoDynamicColor.resolve(
                            AppColors.separator,
                            context,
                          ).withValues(alpha: 0.5),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Symbols.smartphone,
                            size: 20,
                            color: AppColors.success.resolveFrom(context),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Push Alert',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Instan',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textSecondary.resolveFrom(
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
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: CupertinoDynamicColor.resolve(
                          AppColors.groupedBackground,
                          context,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: CupertinoDynamicColor.resolve(
                            AppColors.separator,
                            context,
                          ).withValues(alpha: 0.5),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Symbols.graphic_eq,
                            size: 20,
                            color: AppColors.tint.resolveFrom(context),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Haptic Alert',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Getar Keras',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textSecondary.resolveFrom(
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
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Mandatory Critical Safety Notice Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.danger
                .resolveFrom(context)
                .withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.danger
                  .resolveFrom(context)
                  .withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.danger
                      .resolveFrom(context)
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.danger
                        .resolveFrom(context)
                        .withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Symbols.shield,
                    size: 18,
                    color: AppColors.danger.resolveFrom(context),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Protokol Keselamatan Inti',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.danger.resolveFrom(context),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.danger
                                .resolveFrom(context)
                                .withValues(alpha: 0.20),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: AppColors.danger
                                  .resolveFrom(context)
                                  .withValues(alpha: 0.40),
                              width: 0.6,
                            ),
                          ),
                          child: Text(
                            'WAJIB',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppColors.danger.resolveFrom(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ProfileStrings.notifSosNote,
                      style: AppTextStyles.footnote(
                        context,
                        color: AppColors.textPrimary,
                        emphasized: true,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Peringatan darurat akan menembus mode Hening/Jangan Ganggu demi keselamatan semua anggota keluarga.',
                      style: AppTextStyles.caption2(
                        context,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _set(
    BuildContext context,
    WidgetRef ref,
    NotificationSettings Function(NotificationSettings) apply,
  ) async {
    final cur = ref.read(notificationSettingsProvider).value;
    if (cur == null) return;
    try {
      await ref.read(notificationSettingsProvider.notifier).set(apply(cur));
    } on NotificationSettingsFailure catch (f) {
      if (!context.mounted) return;
      _showError(context, ProfileStrings.notifFailure(f.kind));
    } catch (_) {
      if (!context.mounted) return;
      _showError(
        context,
        ProfileStrings.notifFailure(NotificationSettingsFailureKind.unknown),
      );
    }
  }

  void _showError(BuildContext context, String message) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text(ProfileStrings.errorTitle),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(ProfileStrings.ok),
          ),
        ],
      ),
    );
  }
}

typedef _SwitchChanged = void Function(bool);

class _BentoSwitchCard extends StatelessWidget {
  const _BentoSwitchCard({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.label,
    required this.hint,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String label;
  final String hint;
  final bool value;
  final _SwitchChanged onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: CupertinoDynamicColor.resolve(
            AppColors.groupedItemBackground,
            context,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: CupertinoDynamicColor.resolve(
              AppColors.separator,
              context,
            ).withValues(alpha: 0.35),
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: iconColor.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Center(child: Icon(icon, size: 22, color: iconColor)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.body(context, emphasized: true),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hint,
                    style: AppTextStyles.footnote(
                      context,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            CupertinoSwitch(
              value: value,
              activeTrackColor: AppColors.success.resolveFrom(context),
              onChanged: onChanged,
            ),
          ],
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
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            ProfileStrings.notifLoadFailed,
            textAlign: TextAlign.center,
            style: AppTextStyles.body(context),
          ),
          const SizedBox(height: 12),
          CupertinoButton(
            onPressed: onRetry,
            child: const Text(ProfileStrings.retry),
          ),
        ],
      ),
    );
  }
}
