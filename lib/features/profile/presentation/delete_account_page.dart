import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
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
    final first = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text(DeleteAccountStrings.step1Title),
        content: const Text(DeleteAccountStrings.step1Message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(DeleteAccountStrings.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(DeleteAccountStrings.next),
          ),
        ],
      ),
    );
    if (first != true || !mounted) return;
    final second = await showCupertinoDialog<bool>(
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
    return CupertinoPageScaffold(
      backgroundColor: AppColors.groupedBackground,
      navigationBar: const CupertinoNavigationBar(
        middle: Text(DeleteAccountStrings.title),
      ),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      DeleteAccountStrings.heading,
                      style: AppTextStyles.title2(context, emphasized: true),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    DeleteAccountStrings.intro,
                    style: AppTextStyles.body(context),
                  ),
                  const SizedBox(height: 24),
                  Semantics(
                    header: true,
                    child: Text(
                      DeleteAccountStrings.whatSection.toUpperCase(),
                      style: AppTextStyles.footnote(
                        context,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final item in DeleteAccountStrings.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('•  ', style: AppTextStyles.body(context)),
                          Expanded(
                            child: Text(
                              item,
                              style: AppTextStyles.body(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    DeleteAccountStrings.grace,
                    style: AppTextStyles.footnote(
                      context,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Semantics(
                    button: true,
                    enabled: !_busy,
                    label: _busy
                        ? DeleteAccountStrings.busyLabel
                        : DeleteAccountStrings.button,
                    excludeSemantics: true,
                    onTap: _busy ? null : _start,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: CupertinoDynamicColor.resolve(
                          AppColors.groupedItemBackground,
                          context,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        minimumSize: const Size.fromHeight(44),
                        onPressed: _busy ? null : _start,
                        child: _busy
                            ? const CupertinoActivityIndicator()
                            : Text(
                                DeleteAccountStrings.button,
                                style: AppTextStyles.body(
                                  context,
                                  color: AppColors.danger,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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
    return CupertinoAlertDialog(
      title: const Text(DeleteAccountStrings.step2Title),
      content: Column(
        children: [
          const Text(DeleteAccountStrings.step2Message),
          const SizedBox(height: 12),
          Semantics(
            label: DeleteAccountStrings.fieldLabel,
            child: CupertinoTextField(
              controller: _controller,
              autofocus: true,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.characters,
              placeholder: DeleteAccountStrings.fieldPlaceholder,
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(DeleteAccountStrings.cancel),
        ),
        CupertinoDialogAction(
          isDestructiveAction: true,
          onPressed: _matches ? () => Navigator.of(context).pop(true) : null,
          child: const Text(DeleteAccountStrings.confirm),
        ),
      ],
    );
  }
}
