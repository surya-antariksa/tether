import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/design_widgets.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/glass_dialog.dart';
import '../../auth/data/auth_providers.dart';
import '../../safety/data/safety_providers.dart';
import '../data/profile_providers.dart';
import '../domain/account_repository.dart';
import 'delete_account_strings.dart';

/// Hapus akun (F12) dengan konfirmasi ganda: dialog penjelasan, lalu ketik
/// kata konfirmasi. Sukses -> keluar -> kembali ke /auth.
class DeleteAccountPage extends ConsumerStatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  ConsumerState<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends ConsumerState<DeleteAccountPage> {
  bool _busy = false;

  Future<void> _start() async {
    final first = await showGlassDialog<bool>(
      context: context,
      builder: (ctx) => GlassDialog(
        icon: Symbols.delete,
        title: DeleteAccountStrings.step1Title,
        message: DeleteAccountStrings.step1Message,
        actions: [
          GlassDialogAction(
            label: DeleteAccountStrings.cancel,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          GlassDialogAction(
            label: DeleteAccountStrings.next,
            destructive: true,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    if (first != true || !mounted) return;
    final second = await showGlassDialog<bool>(
      context: context,
      builder: (_) => const _TypeToConfirmDialog(),
    );
    if (second != true || !mounted) return;
    await _delete();
  }

  Future<void> _delete() async {
    setState(() => _busy = true);
    final uid = ref.read(currentUserIdProvider);
    try {
      await ref.read(accountRepositoryProvider).deleteAccount();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      final kind = e is AccountFailure ? e.kind : AccountFailureKind.unknown;
      await _alert(DeleteAccountStrings.failure(kind));
      return;
    }
    // Koordinat SOS tertunda milik akun ini tidak boleh tertinggal di perangkat.
    if (uid != null) {
      try {
        final store = await ref.read(sosQueueStoreProvider.future);
        await store.removeForUser(uid);
      } catch (_) {}
    }
    // Server sudah menonaktifkan akun dan mencabut sesi; bersihkan sesi lokal.
    try {
      await ref.read(authRepositoryProvider).signOut();
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      await _alert(DeleteAccountStrings.signOutFailed);
      return;
    }
    // Auth gate biasanya sudah mengalihkan; ini pengaman bila belum.
    if (mounted) context.go(AppRoutes.auth);
  }

  Future<void> _alert(String message) {
    return showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text(DeleteAccountStrings.errorTitle),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(DeleteAccountStrings.ok),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const icons = [
      Symbols.location_on,
      Symbols.warning,
      Symbols.smartphone,
      Symbols.group,
    ];
    final danger = AppColors.danger.resolveFrom(context);
    return CupertinoPageScaffold(
      backgroundColor: AppColors.groupedBackground,
      navigationBar: const CupertinoNavigationBar(
        middle: Text(DeleteAccountStrings.title),
      ),
      child: AtmosphereBackground(
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: IconTile(
                        icon: Symbols.delete,
                        color: AppColors.danger,
                        size: 56,
                        iconSize: 26,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Semantics(
                      header: true,
                      child: Text(
                        DeleteAccountStrings.heading,
                        style: AppTextStyles.title1(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      DeleteAccountStrings.intro,
                      style: AppTextStyles.callout(
                        context,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SectionLabel(
                      DeleteAccountStrings.whatSection,
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: danger.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: danger.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          DeleteAccountStrings.permanent,
                          style: AppTextStyles.caption2(
                            context,
                            emphasized: true,
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    GlassCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (
                            var i = 0;
                            i < DeleteAccountStrings.items.length;
                            i++
                          ) ...[
                            if (i > 0)
                              Container(
                                height: 1,
                                color: AppColors.separator.resolveFrom(context),
                              ),
                            Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  IconTile(
                                    icon: icons[i],
                                    color: AppColors.danger,
                                    size: 36,
                                    iconSize: 20,
                                    filled: false,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _ItemText(
                                      DeleteAccountStrings.items[i],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    GlassCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Symbols.schedule,
                            size: 22,
                            color: AppColors.tint.resolveFrom(context),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              DeleteAccountStrings.grace,
                              style: AppTextStyles.footnote(
                                context,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Semantics(
                      button: true,
                      enabled: !_busy,
                      label: _busy
                          ? DeleteAccountStrings.busyLabel
                          : DeleteAccountStrings.button,
                      excludeSemantics: true,
                      onTap: _busy ? null : _start,
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size.fromHeight(52),
                        onPressed: _busy ? null : _start,
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 52),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: danger.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: danger.withValues(alpha: 0.4),
                            ),
                          ),
                          child: _busy
                              ? const CupertinoActivityIndicator()
                              : Text(
                                  DeleteAccountStrings.button,
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.body(
                                    context,
                                    emphasized: true,
                                    color: AppColors.danger,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Satu butir "yang dihapus": kalimat pertama tebal, sisanya keterangan.
class _ItemText extends StatelessWidget {
  const _ItemText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final cut = text.indexOf('. ');
    final head = cut < 0 ? text : text.substring(0, cut + 1);
    final tail = cut < 0 ? '' : text.substring(cut + 2);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: head,
            style: AppTextStyles.callout(context, emphasized: true),
          ),
          if (tail.isNotEmpty)
            TextSpan(
              text: '\n$tail',
              style: AppTextStyles.footnote(
                context,
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

/// Konfirmasi kedua: tombol hapus aktif hanya bila kata konfirmasi diketik.
class _TypeToConfirmDialog extends StatefulWidget {
  const _TypeToConfirmDialog();

  @override
  State<_TypeToConfirmDialog> createState() => _TypeToConfirmDialogState();
}

class _TypeToConfirmDialogState extends State<_TypeToConfirmDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _matches =>
      _controller.text.trim().toUpperCase() == DeleteAccountStrings.confirmWord;

  @override
  Widget build(BuildContext context) {
    return GlassDialog(
      icon: Symbols.delete,
      title: DeleteAccountStrings.step2Title,
      message: DeleteAccountStrings.step2Message,
      // ignore: sort_child_properties_last
      child: Semantics(
        label: DeleteAccountStrings.fieldLabel,
        child: CupertinoTextField(
          controller: _controller,
          autofocus: true,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.characters,
          placeholder: DeleteAccountStrings.fieldPlaceholder,
          textAlign: TextAlign.center,
          padding: const EdgeInsets.all(14),
          style: AppTextStyles.body(context, emphasized: true),
          placeholderStyle: AppTextStyles.body(
            context,
            color: AppColors.textTertiary,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh.resolveFrom(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.separator.resolveFrom(context)),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ),
      actions: [
        GlassDialogAction(
          label: DeleteAccountStrings.cancel,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        GlassDialogAction(
          label: DeleteAccountStrings.confirm,
          destructive: true,
          onPressed: _matches ? () => Navigator.of(context).pop(true) : null,
        ),
      ],
    );
  }
}
