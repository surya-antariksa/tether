import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/theme_mode_provider.dart';
import '../../../core/member_colors.dart';
import '../../../core/widgets/design_widgets.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/glass_dialog.dart';
import '../../../core/widgets/member_avatar.dart';
import '../../auth/data/auth_providers.dart';
import '../../auth/domain/auth_validators.dart';
import '../data/profile_providers.dart';
import '../domain/profile.dart';
import '../domain/profile_repository.dart';
import '../profile_routes.dart';
import 'profile_strings.dart';
import 'edit_profile_sheet.dart';
import 'settings_row.dart';

class ProfileTabPage extends ConsumerWidget {
  const ProfileTabPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(ownProfileProvider);
    return CupertinoPageScaffold(
      backgroundColor: AppColors.groupedBackground,
      child: AtmosphereBackground(
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          ProfileStrings.title,
                          style: AppTextStyles.largeTitle(
                            context,
                            emphasized: true,
                          ),
                        ),
                      ),
                      Text(
                        ProfileStrings.subtitle,
                        style: AppTextStyles.footnote(
                          context,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
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
            ],
          ),
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
    final tint = AppColors.tint.resolveFrom(context);
    final dark = AppColors.isDark(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: tint, width: 3),
                      boxShadow: dark
                          ? [
                              BoxShadow(
                                color: tint.withValues(alpha: 0.35),
                                blurRadius: 20,
                              ),
                            ]
                          : null,
                    ),
                    child: MemberAvatar(
                      name: profile.displayName,
                      colorHex: profile.color,
                      size: 88,
                      semanticLabel: ProfileStrings.avatarLabel(
                        profile.displayName,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  profile.displayName,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.title2(context, emphasized: true),
                ),
                const SizedBox(height: 16),
                _ActionRow(
                  icon: Symbols.edit,
                  title: ProfileStrings.editName,
                  onPressed: () => _rename(context, ref),
                ),
                const SizedBox(height: 8),
                _ActionRow(
                  icon: Symbols.tune,
                  title: 'Ubah Profil Publik Circle',
                  subtitle: 'Nama tampilan & warna penanda peta',
                  onPressed: () => showEditProfileSheet(
                    context,
                    profile: profile,
                    onSave: ({displayName, color}) => ref
                        .read(ownProfileProvider.notifier)
                        .updateProfile(displayName: displayName, color: color),
                  ),
                ),
              ],
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
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(
              ProfileStrings.colorFooter,
              style: AppTextStyles.footnote(
                context,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 24),
          _SectionHeader(ProfileStrings.appearanceSection),
          const _ThemePicker(),
          const SizedBox(height: 24),
          _SectionHeader(ProfileStrings.settingsSection),
          SettingsRow(
            icon: Symbols.history,
            label: ProfileStrings.historyRow,
            subtitle: ProfileStrings.historySubtitle,
            onPressed: () =>
                context.push('${AppRoutes.profile}/${ProfileRoutes.history}'),
          ),
          const SizedBox(height: 10),
          SettingsRow(
            icon: Symbols.notifications,
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
                  vertical: 14,
                ),
                child: Semantics(
                  label: ProfileStrings.accountLabel(profile.email!),
                  excludeSemantics: true,
                  child: Row(
                    children: [
                      Icon(
                        Symbols.mail,
                        size: 20,
                        color: AppColors.textSecondary.resolveFrom(context),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          profile.email!,
                          style: AppTextStyles.callout(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          const _SignOutButton(),
          const SizedBox(height: 10),
          SettingsRow(
            icon: Symbols.delete,
            label: ProfileStrings.deleteAccount,
            destructive: true,
            onPressed: () => context.push(
              '${AppRoutes.profile}/${ProfileRoutes.deleteAccount}',
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
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

/// Pemilih tema: Sistem, Terang, atau Gelap. Berlaku langsung dan disimpan.
class _ThemePicker extends ConsumerWidget {
  const _ThemePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    const labels = {
      AppThemeMode.system: ProfileStrings.themeSystem,
      AppThemeMode.light: ProfileStrings.themeLight,
      AppThemeMode.dark: ProfileStrings.themeDark,
    };
    const icons = {
      AppThemeMode.system: Symbols.contrast,
      AppThemeMode.light: Symbols.light_mode,
      AppThemeMode.dark: Symbols.dark_mode,
    };
    return _Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ProfileStrings.appearanceTitle,
              style: AppTextStyles.body(context, emphasized: true),
            ),
            const SizedBox(height: 2),
            Text(
              ProfileStrings.appearanceHint,
              style: AppTextStyles.footnote(
                context,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (final m in AppThemeMode.values) ...[
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: m == mode,
                      label: '${ProfileStrings.appearanceTitle}: ${labels[m]}',
                      excludeSemantics: true,
                      onTap: () =>
                          ref.read(themeModeProvider.notifier).select(m),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () =>
                            ref.read(themeModeProvider.notifier).select(m),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          constraints: const BoxConstraints(minHeight: 64),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: m == mode
                                ? AppColors.tint
                                      .resolveFrom(context)
                                      .withValues(alpha: 0.12)
                                : AppColors.surfaceHigh.resolveFrom(context),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: m == mode
                                  ? AppColors.tint.resolveFrom(context)
                                  : AppColors.separator.resolveFrom(context),
                              width: m == mode ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                icons[m],
                                size: 22,
                                color: m == mode
                                    ? AppColors.tint.resolveFrom(context)
                                    : AppColors.textSecondary.resolveFrom(
                                        context,
                                      ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                labels[m]!,
                                style: AppTextStyles.caption1(
                                  context,
                                  emphasized: m == mode,
                                  color: m == mode
                                      ? AppColors.tint
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (m != AppThemeMode.values.last) const SizedBox(width: 8),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Baris aksi di dalam kartu identitas: ikon, judul, keterangan, chevron.
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.onPressed,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: subtitle == null ? title : '$title, $subtitle',
      excludeSemantics: true,
      onTap: onPressed,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh.resolveFrom(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.separator.resolveFrom(context),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: AppColors.tint.resolveFrom(context),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.callout(context, emphasized: true),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: AppTextStyles.footnote(
                            context,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  Symbols.chevron_right,
                  size: 18,
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

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlassCard(padding: EdgeInsets.zero, child: child);
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SectionLabel(text),
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
                border: selected
                    ? Border.all(
                        color: AppColors.textPrimary.resolveFrom(context),
                        width: 2,
                      )
                    : null,
              ),
              // Tanda centang: pilihan tidak hanya lewat warna.
              child: selected
                  ? Icon(
                      Symbols.check,
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
    final ok = await showGlassDialog<bool>(
      context: context,
      builder: (ctx) => GlassDialog(
        icon: Symbols.logout,
        title: ProfileStrings.signOutTitle,
        message: ProfileStrings.signOutMessage,
        note: ProfileStrings.signOutNote,
        actions: [
          GlassDialogAction(
            label: ProfileStrings.cancel,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          GlassDialogAction(
            label: ProfileStrings.signOut,
            destructive: true,
            onPressed: () => Navigator.of(ctx).pop(true),
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
        minimumSize: const Size.fromHeight(48),
        onPressed: () => _confirm(context, ref),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Symbols.logout,
              size: 20,
              color: AppColors.danger.resolveFrom(context),
            ),
            const SizedBox(width: 8),
            Text(
              ProfileStrings.signOut,
              style: AppTextStyles.body(
                context,
                emphasized: true,
                color: AppColors.danger,
              ),
            ),
          ],
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
