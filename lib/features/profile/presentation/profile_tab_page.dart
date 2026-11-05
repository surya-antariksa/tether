import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/member_colors.dart';
import '../../../core/widgets/member_avatar.dart';
import '../../auth/data/auth_providers.dart';
import '../../auth/domain/auth_validators.dart';
import '../data/profile_providers.dart';
import '../domain/profile.dart';
import '../domain/profile_repository.dart';
import '../profile_routes.dart';
import 'profile_strings.dart';
import 'settings_row.dart';

class ProfileTabPage extends ConsumerWidget {
  const ProfileTabPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(ownProfileProvider);
    return CupertinoPageScaffold(
      backgroundColor: AppColors.groupedBackground,
      child: CustomScrollView(
        slivers: [
          const CupertinoSliverNavigationBar(
            largeTitle: Text(ProfileStrings.title),
          ),
          SliverSafeArea(
            top: false,
            sliver: SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: profile.when(
                    data: (p) => _ProfileContent(profile: p),
                    loading: () => const Padding(
                      padding: EdgeInsets.all(48),
                      child: Center(child: CupertinoActivityIndicator()),
                    ),
                    error: (_, _) => _LoadFailed(
                      onRetry: () => ref.invalidate(ownProfileProvider),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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
            ProfileStrings.loadFailed,
            textAlign: TextAlign.center,
            style: AppTextStyles.body(context),
          ),
          const SizedBox(height: 12),
          CupertinoButton(
            onPressed: onRetry,
            child: const Text(ProfileStrings.retry),
          ),
          const SizedBox(height: 24),
          const _SignOutButton(),
        ],
      ),
    );
  }
}

class _ProfileContent extends ConsumerWidget {
  const _ProfileContent({required this.profile});

  final Profile profile;

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } on ProfileFailure catch (f) {
      if (!context.mounted) return;
      await _showError(context, ProfileStrings.failure(f.kind));
    } catch (_) {
      if (!context.mounted) return;
      await _showError(
        context,
        ProfileStrings.failure(ProfileFailureKind.unknown),
      );
    }
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final name = await showCupertinoDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(initial: profile.displayName),
    );
    if (name == null || name == profile.displayName || !context.mounted) return;
    await _run(
      context,
      () => ref
          .read(ownProfileProvider.notifier)
          .updateProfile(displayName: name),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: MemberAvatar(
              name: profile.displayName,
              colorHex: profile.color,
              size: 88,
              semanticLabel: ProfileStrings.avatarLabel(profile.displayName),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            profile.displayName,
            textAlign: TextAlign.center,
            style: AppTextStyles.title2(context, emphasized: true),
          ),
          const SizedBox(height: 24),
          _Card(
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              minimumSize: const Size.fromHeight(44),
              alignment: AlignmentDirectional.centerStart,
              onPressed: () => _rename(context, ref),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      ProfileStrings.editName,
                      style: AppTextStyles.body(context, color: AppColors.tint),
                    ),
                  ),
                  Icon(
                    CupertinoIcons.chevron_forward,
                    size: 18,
                    color: CupertinoDynamicColor.resolve(
                      AppColors.textSecondary,
                      context,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _SectionHeader(ProfileStrings.colorSection),
          _Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < MemberColors.hexes.length; i++)
                    _Swatch(
                      name: ProfileStrings.colorNames[i],
                      hex: MemberColors.hexes[i],
                      selected:
                          MemberColors.hexes[i].toLowerCase() ==
                          profile.color.toLowerCase(),
                      onTap: () => _run(
                        context,
                        () => ref
                            .read(ownProfileProvider.notifier)
                            .updateProfile(color: MemberColors.hexes[i]),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              ProfileStrings.colorFooter,
              style: AppTextStyles.footnote(
                context,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 24),
          SettingsRow(
            label: ProfileStrings.historyRow,
            subtitle: ProfileStrings.historySubtitle,
            onPressed: () =>
                context.push('${AppRoutes.profile}/${ProfileRoutes.history}'),
          ),
          const SizedBox(height: 12),
          SettingsRow(
            label: ProfileStrings.notificationRow,
            subtitle: ProfileStrings.notificationSubtitle,
            onPressed: () => context.push(
              '${AppRoutes.profile}/${ProfileRoutes.notifications}',
            ),
          ),
          const SizedBox(height: 24),
          if (profile.email != null) ...[
            _SectionHeader(ProfileStrings.accountSection),
            _Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Semantics(
                  label: ProfileStrings.accountLabel(profile.email!),
                  excludeSemantics: true,
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      profile.email!,
                      style: AppTextStyles.body(context),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          const _SignOutButton(),
          const SizedBox(height: 16),
          SettingsRow(
            label: ProfileStrings.deleteAccount,
            destructive: true,
            onPressed: () => context.push(
              '${AppRoutes.profile}/${ProfileRoutes.deleteAccount}',
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              ProfileStrings.privacyNote,
              style: AppTextStyles.footnote(
                context,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CupertinoDynamicColor.resolve(
          AppColors.groupedItemBackground,
          context,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Semantics(
        header: true,
        child: Text(
          text.toUpperCase(),
          style: AppTextStyles.footnote(
            context,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.name,
    required this.hex,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final String hex;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: ProfileStrings.colorLabel(name),
      value: selected ? ProfileStrings.colorSelected : null,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // Area sentuh 44x44; gambar 36.
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: MemberColors.toColor(hex),
              ),
              // Tanda centang: pilihan tidak hanya lewat warna.
              child: selected
                  ? Icon(
                      CupertinoIcons.checkmark_alt,
                      size: 22,
                      color: MemberColors.onColor(hex),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _SignOutButton extends ConsumerWidget {
  const _SignOutButton();

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text(ProfileStrings.signOutTitle),
        content: const Text(ProfileStrings.signOutMessage),
        actions: [
          // Batal bukan tombol bawaan pada alert destruktif.
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(ProfileStrings.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(ProfileStrings.signOut),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(authRepositoryProvider).signOut();
    } catch (_) {
      if (!context.mounted) return;
      await _showError(
        context,
        ProfileStrings.failure(ProfileFailureKind.unknown),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Card(
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        minimumSize: const Size.fromHeight(44),
        onPressed: () => _confirm(context, ref),
        child: Text(
          ProfileStrings.signOut,
          style: AppTextStyles.body(context, color: AppColors.danger),
        ),
      ),
    );
  }
}

Future<void> _showError(BuildContext context, String message) {
  return showCupertinoDialog<void>(
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

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});

  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _controller = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final error = AuthValidators.displayName(_controller.text);
    if (error != null) {
      setState(() {
        _error = error == AuthFieldError.nameEmpty
            ? ProfileStrings.nameEmpty
            : ProfileStrings.nameTooLong;
      });
      return;
    }
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: const Text(ProfileStrings.nameDialogTitle),
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          children: [
            Semantics(
              label: ProfileStrings.nameSection,
              child: CupertinoTextField(
                controller: _controller,
                autofocus: true,
                placeholder: ProfileStrings.namePlaceholder,
                textCapitalization: TextCapitalization.words,
                onSubmitted: (_) => _save(),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: AppTextStyles.footnote(context)),
              ),
          ],
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(ProfileStrings.cancel),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: _save,
          child: const Text(ProfileStrings.save),
        ),
      ],
    );
  }
}
