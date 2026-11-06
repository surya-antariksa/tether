import 'package:flutter/cupertino.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/theme/app_colors.dart';
import '../domain/auth_validators.dart';
import 'auth_strings.dart';

/// Menampilkan sheet modal Lupa Kata Sandi bertema Obsidian Dark Glass.
Future<void> showForgotPasswordSheet(
  BuildContext context, {
  required Future<void> Function(String email) onReset,
}) {
  return showCupertinoModalPopup<void>(
    context: context,
    builder: (_) => ForgotPasswordSheet(onReset: onReset),
  );
}

/// Sheet modal untuk pemulihan akun dan reset kata sandi via email.
class ForgotPasswordSheet extends StatefulWidget {
  const ForgotPasswordSheet({super.key, required this.onReset});

  final Future<void> Function(String email) onReset;

  @override
  State<ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<ForgotPasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || _sent) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await widget.onReset(_emailController.text.trim());
      if (mounted) {
        setState(() {
          _busy = false;
          _sent = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Gagal mengirim tautan. Periksa koneksi internet Anda.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: CupertinoTheme.of(context).textTheme.textStyle,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: CupertinoDynamicColor.resolve(
                AppColors.groupedBackground,
                context,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              border: Border(
                top: BorderSide(
                  color: AppColors.tint
                      .resolveFrom(context)
                      .withValues(alpha: 0.20),
                  width: 0.8,
                ),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x80000000),
                  blurRadius: 24,
                  offset: Offset(0, -6),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Drag Handle
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: AppColors.textTertiary
                              .resolveFrom(context)
                              .withValues(alpha: 0.40),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),

                    // Header & Close
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.tint
                                .resolveFrom(context)
                                .withValues(alpha: 0.15),
                            border: Border.all(
                              color: AppColors.tint
                                  .resolveFrom(context)
                                  .withValues(alpha: 0.30),
                            ),
                          ),
                          child: Icon(
                            Symbols.lock_reset,
                            color: AppColors.tint.resolveFrom(context),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AuthStrings.forgotPasswordTitle,
                                style: TextStyle(
                                  fontFamily: 'Plus Jakarta Sans',
                                  color: AppColors.textPrimary.resolveFrom(
                                    context,
                                  ),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                AuthStrings.forgotPasswordSubtitle,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  color: AppColors.textTertiary.resolveFrom(
                                    context,
                                  ),
                                  fontSize: 12,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(32, 32),
                          onPressed: () => Navigator.of(context).pop(),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.separator
                                  .resolveFrom(context)
                                  .withValues(alpha: 0.15),
                            ),
                            child: Icon(
                              Symbols.close,
                              size: 16,
                              color: AppColors.textPrimary.resolveFrom(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    if (_sent) ...[
                      // Success View
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.success
                              .resolveFrom(context)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.success
                                .resolveFrom(context)
                                .withValues(alpha: 0.40),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Symbols.check_circle,
                              color: AppColors.success.resolveFrom(context),
                              size: 22,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                AuthStrings.resetEmailSent,
                                style: TextStyle(
                                  fontFamily: 'Plus Jakarta Sans',
                                  color: AppColors.textPrimary.resolveFrom(
                                    context,
                                  ),
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Semantics(
                        button: true,
                        label: 'Tutup',
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 48),
                          decoration: BoxDecoration(
                            color: AppColors.tint
                                .resolveFrom(context)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.tint
                                  .resolveFrom(context)
                                  .withValues(alpha: 0.30),
                            ),
                          ),
                          child: CupertinoButton(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(
                              'Tutup',
                              style: TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                color: AppColors.tint.resolveFrom(context),
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      // Form View
                      Form(
                        key: _formKey,
                        child: CupertinoFormSection.insetGrouped(
                          margin: EdgeInsets.zero,
                          children: [
                            Semantics(
                              label: AuthStrings.emailLabel,
                              child: CupertinoTextFormFieldRow(
                                controller: _emailController,
                                placeholder: AuthStrings.emailPlaceholder,
                                enabled: !_busy,
                                keyboardType: TextInputType.emailAddress,
                                autocorrect: false,
                                enableSuggestions: true,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [AutofillHints.email],
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
                                validator: (v) {
                                  final err = AuthValidators.email(v);
                                  return err == null
                                      ? null
                                      : AuthStrings.fieldError(err);
                                },
                                onFieldSubmitted: (_) => _submit(),
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Symbols.error,
                                size: 18,
                                color: AppColors.danger.resolveFrom(context),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    color: AppColors.danger.resolveFrom(
                                      context,
                                    ),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),
                      Semantics(
                        button: true,
                        enabled: !_busy,
                        label: _busy
                            ? AuthStrings.processing
                            : AuthStrings.sendResetLink,
                        excludeSemantics: true,
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 48),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.tint.resolveFrom(context),
                                AppColors.tint.resolveFrom(context),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.tint
                                    .resolveFrom(context)
                                    .withValues(alpha: 0.40),
                                blurRadius: 14,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: CupertinoButton(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            minimumSize: const Size.fromHeight(48),
                            onPressed: _busy ? null : _submit,
                            child: _busy
                                ? CupertinoActivityIndicator(
                                    color: AppColors.groupedBackground
                                        .resolveFrom(context),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Symbols.send,
                                        size: 16,
                                        color: AppColors.groupedBackground
                                            .resolveFrom(context),
                                      ),
                                      SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          AuthStrings.sendResetLink,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontFamily: 'Plus Jakarta Sans',
                                            color: AppColors.groupedBackground
                                                .resolveFrom(context),
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    // Footnote
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Symbols.shield,
                          size: 13,
                          color: AppColors.success.resolveFrom(context),
                        ),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Pemulihan akun aman • Tautan berlaku 1 jam',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: AppColors.textTertiary.resolveFrom(
                                context,
                              ),
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
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
