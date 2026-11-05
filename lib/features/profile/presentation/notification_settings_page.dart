import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../data/profile_providers.dart';
import '../domain/notification_settings.dart';
import 'profile_strings.dart';

/// Pengaturan notifikasi: tiga sakelar (notification_settings). SOS tidak ada
/// di sini karena selalu dikirim (lihat 20261104130400).
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _SwitchCard(
          label: ProfileStrings.notifArriveLeave,
          hint: ProfileStrings.notifArriveLeaveHint,
          value: settings.arriveLeave,
          onChanged: (v) =>
              _set(context, ref, (cur) => cur.copyWith(arriveLeave: v)),
        ),
        _SwitchCard(
          label: ProfileStrings.notifCheckin,
          hint: ProfileStrings.notifCheckinHint,
          value: settings.checkin,
          onChanged: (v) =>
              _set(context, ref, (cur) => cur.copyWith(checkin: v)),
        ),
        _SwitchCard(
          label: ProfileStrings.notifMemberChanges,
          hint: ProfileStrings.notifMemberChangesHint,
          value: settings.memberChanges,
          onChanged: (v) =>
              _set(context, ref, (cur) => cur.copyWith(memberChanges: v)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            ProfileStrings.notifSosNote,
            style: AppTextStyles.footnote(
              context,
              color: AppColors.textSecondary,
            ),
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
      await ref
          .read(notificationSettingsProvider.notifier)
          .set(apply(cur));
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

class _SwitchCard extends StatelessWidget {
  const _SwitchCard({
    required this.label,
    required this.hint,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String hint;
  final bool value;
  final _SwitchChanged onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: CupertinoDynamicColor.resolve(
            AppColors.groupedItemBackground,
            context,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: CupertinoListTile(
          title: Text(label, style: AppTextStyles.body(context)),
          subtitle: Text(
            hint,
            style: AppTextStyles.footnote(
              context,
              color: AppColors.textSecondary,
            ),
          ),
          trailing: CupertinoSwitch(value: value, onChanged: onChanged),
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
        children: [
          Text(
            ProfileStrings.notifLoadFailed,
            textAlign: TextAlign.center,
            style: AppTextStyles.body(context),
          ),
          const SizedBox(height: 12),
          CupertinoButton(onPressed: onRetry, child: const Text(ProfileStrings.retry)),
        ],
      ),
    );
  }
}
