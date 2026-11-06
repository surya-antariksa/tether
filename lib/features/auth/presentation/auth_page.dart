import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/auth_providers.dart';
import '../data/session_confirm.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_validators.dart';
import 'auth_strings.dart';
import 'forgot_password_sheet.dart';
import 'session_verify_dialog.dart';

enum _Mode { signIn, signUp }

/// Halaman Autentikasi bertema Obsidian Dark Glass sesuai desain mockups Tether.
/// Menggabungkan hero beacon quantum, tab switcher kapsul kaca, form card
/// glassmorphism, dan cyan radiant CTA.
class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  _Mode _mode = _Mode.signIn;
  bool _busy = false;
  bool _obscurePassword = true;
  String? _message;
  bool _messageIsError = false;

  void _openForgotPassword() {
    showForgotPasswordSheet(
      context,
      onReset: (email) =>
          ref.read(authRepositoryProvider).resetPassword(email: email),
    );
  }

  @override
  void dispose() {
    // Bila halaman hilang saat pop-up masih ada, tutup sesudah frame ini.
    final open = _verifyRoute;
    _verifyRoute = null;
    if (open != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (open.isActive) open.navigator?.removeRoute(open);
      });
    }
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  String? _validate(AuthFieldError? e) =>
      e == null ? null : AuthStrings.fieldError(e);

  Route<void>? _verifyRoute;

  /// Membuka pop-up verifikasi sesi segera (di atas halaman masuk).
  void _openVerify() {
    if (_verifyRoute != null) return;
    final route = CupertinoDialogRoute<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0xB3000000),
      builder: (_) => SessionVerifyDialog(
        onContinue: _finishVerify,
        onSwitch: _switchAccount,
      ),
    );
    _verifyRoute = route;
    Navigator.of(context, rootNavigator: true).push(route);
  }

  void _closeVerify() {
    final r = _verifyRoute;
    _verifyRoute = null;
    if (r != null && r.isActive) r.navigator?.removeRoute(r);
  }

  /// "Lanjutkan ke Peta": tutup pop-up lalu lepas penahan router.
  void _finishVerify() {
    final confirm = ref.read(sessionConfirmProvider.notifier);
    _closeVerify();
    confirm.clear();
  }

  /// "Ganti Akun / Batal": keluar dari sesi yang baru dibuat.
  Future<void> _switchAccount() async {
    final confirm = ref.read(sessionConfirmProvider.notifier);
    try {
      await ref.read(authRepositoryProvider).signOut();
    } catch (_) {}
    _closeVerify();
    confirm.clear();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    final repo = ref.read(authRepositoryProvider);
    final confirm = ref.read(sessionConfirmProvider.notifier);
    setState(() {
      _busy = true;
      _message = null;
    });
    // Pop-up verifikasi langsung tampil; router menahan di /auth sesudah masuk.
    confirm.request();
    _openVerify();
    try {
      if (_mode == _Mode.signIn) {
        await repo.signIn(email: _email.text, password: _password.text);
      } else {
        final outcome = await repo.signUp(
          email: _email.text,
          password: _password.text,
          displayName: _name.text,
        );
        if (outcome == SignUpOutcome.confirmationRequired) {
          _closeVerify();
          confirm.clear();
        }
        if (outcome == SignUpOutcome.confirmationRequired && mounted) {
          setState(() {
            _mode = _Mode.signIn;
            _password.clear();
            _message = AuthStrings.confirmationRequired;
            _messageIsError = false;
          });
        }
      }
    } on AuthFailure catch (f) {
      _closeVerify();
      confirm.clear();
      if (mounted) {
        setState(() {
          _message = AuthStrings.failure(f.kind);
          _messageIsError = true;
        });
      }
    } catch (_) {
      _closeVerify();
      confirm.clear();
      if (mounted) {
        setState(() {
          _message = AuthStrings.failure(AuthFailureKind.unknown);
          _messageIsError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _setMode(_Mode mode) {
    if (mode == _mode) return;
    setState(() {
      _mode = mode;
      _message = null;
    });
    _formKey.currentState?.reset();
  }

  @override
  Widget build(BuildContext context) {
    final signUp = _mode == _Mode.signUp;
    final dark = AppColors.isDark(context);
    final tint = AppColors.tint.resolveFrom(context);
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      child: Stack(
        children: [
          // Cahaya latar hanya di mode gelap.
          if (dark) ...[
            Positioned(
              top: -100,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    width: 380,
                    height: 380,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          tint.withValues(alpha: 0.20),
                          tint.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -120,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    width: 460,
                    height: 360,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.success
                              .resolveFrom(context)
                              .withValues(alpha: 0.10),
                          AppColors.success
                              .resolveFrom(context)
                              .withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                  children: [
                    _Logo(dark: dark),
                    const SizedBox(height: 16),
                    Semantics(
                      header: true,
                      child: Text(
                        AuthStrings.title,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.largeTitle(context),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      AuthStrings.subtitle,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.callout(
                        context,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _ModeSwitch(
                      signUp: signUp,
                      enabled: !_busy,
                      onChanged: _setMode,
                    ),
                    const SizedBox(height: 16),
                    Form(
                      key: _formKey,
                      child: GlassCard(
                        radius: 20,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (signUp) ...[
                              _AuthField(
                                semanticLabel: AuthStrings.nameLabel,
                                label: AuthStrings.nameFieldLabel,
                                hint: AuthStrings.nameFieldHint,
                                icon: Symbols.person,
                                controller: _name,
                                placeholder: AuthStrings.namePlaceholder,
                                enabled: !_busy,
                                textInputAction: TextInputAction.next,
                                textCapitalization: TextCapitalization.words,
                                autofillHints: const [AutofillHints.name],
                                enableSuggestions: true,
                                validator: (v) =>
                                    _validate(AuthValidators.displayName(v)),
                              ),
                              const SizedBox(height: 14),
                            ],
                            _AuthField(
                              semanticLabel: AuthStrings.emailLabel,
                              label: AuthStrings.emailLabel,
                              icon: Symbols.mail,
                              controller: _email,
                              placeholder: AuthStrings.emailPlaceholder,
                              enabled: !_busy,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.email],
                              enableSuggestions: true,
                              validator: (v) =>
                                  _validate(AuthValidators.email(v)),
                            ),
                            const SizedBox(height: 14),
                            _AuthField(
                              semanticLabel: AuthStrings.passwordLabel,
                              label: AuthStrings.passwordFieldLabel,
                              icon: Symbols.lock,
                              controller: _password,
                              placeholder: AuthStrings.passwordPlaceholder,
                              enabled: !_busy,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              autofillHints: [
                                signUp
                                    ? AutofillHints.newPassword
                                    : AutofillHints.password,
                              ],
                              enableSuggestions: false,
                              validator: (v) =>
                                  _validate(AuthValidators.password(v)),
                              onSubmitted: _submit,
                              trailingLabel: signUp
                                  ? null
                                  : GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: _openForgotPassword,
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          minHeight: 24,
                                        ),
                                        child: Text(
                                          AuthStrings.forgotPasswordLink,
                                          style: AppTextStyles.caption1(
                                            context,
                                            emphasized: true,
                                            color: AppColors.tint,
                                          ),
                                        ),
                                      ),
                                    ),
                              trailing: ExcludeSemantics(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Icon(
                                      _obscurePassword
                                          ? Symbols.visibility
                                          : Symbols.visibility_off,
                                      size: 20,
                                      color: AppColors.textTertiary.resolveFrom(
                                        context,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (_message != null) ...[
                              const SizedBox(height: 14),
                              _MessageRow(
                                message: _message!,
                                isError: _messageIsError,
                              ),
                            ],
                            const SizedBox(height: 18),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                boxShadow: dark
                                    ? [
                                        BoxShadow(
                                          color: tint.withValues(alpha: 0.35),
                                          blurRadius: 20,
                                          offset: const Offset(0, 4),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: PrimaryButton(
                                label: signUp
                                    ? AuthStrings.submitSignUp
                                    : AuthStrings.submitSignIn,
                                busyLabel: AuthStrings.processing,
                                // Tanpa putaran di tombol: pop-up yang menunjukkan proses.
                                trailingIcon: Symbols.arrow_forward,
                                onPressed: _submit,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const _OrDivider(),
                            const SizedBox(height: 16),
                            _GoogleButton(enabled: !_busy),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Symbols.shield,
                          size: 14,
                          color: AppColors.success.resolveFrom(context),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            AuthStrings.e2eTrust,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.caption1(
                              context,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const _TermsFooter(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ikon aplikasi dengan lingkar cahaya (gelap) di atas alas kaca.
class _Logo extends StatelessWidget {
  const _Logo({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    final tint = AppColors.tint.resolveFrom(context);
    return Center(
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.separator.resolveFrom(context),
            width: 1.2,
          ),
          boxShadow: [
            if (dark)
              BoxShadow(color: tint.withValues(alpha: 0.35), blurRadius: 28)
            else
              const BoxShadow(
                color: Color(0x1F000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(19),
          child: Image.asset(
            dark
                ? 'assets/branding/app_icon_dark.png'
                : 'assets/branding/app_icon.png',
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}

/// Segmen Masuk / Daftar lebar penuh.
class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({
    required this.signUp,
    required this.enabled,
    required this.onChanged,
  });

  final bool signUp;
  final bool enabled;
  final ValueChanged<_Mode> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget seg(String text, bool selected, _Mode mode) => Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        excludeSemantics: true,
        label: text,
        onTap: enabled ? () => onChanged(mode) : null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? () => onChanged(mode) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            constraints: const BoxConstraints(minHeight: 44),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.surfaceHigh.resolveFrom(context)
                  : const Color(0x00000000),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? AppColors.separator.resolveFrom(context)
                    : const Color(0x00000000),
              ),
            ),
            child: Text(
              text,
              style: AppTextStyles.labelMd(
                context,
                color: selected
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.groupedItemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.separator.resolveFrom(context)),
      ),
      child: Row(
        children: [
          seg(AuthStrings.modeSignIn, !signUp, _Mode.signIn),
          seg(AuthStrings.modeSignUp, signUp, _Mode.signUp),
        ],
      ),
    );
  }
}

/// Satu kolom isian: label (dan keterangan kanan), kotak dengan ikon di kiri
/// dan aksi opsional di kanan, lalu pesan galat DI BAWAH kotak.
class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.semanticLabel,
    required this.label,
    required this.icon,
    required this.controller,
    required this.placeholder,
    required this.validator,
    required this.enabled,
    required this.textInputAction,
    required this.autofillHints,
    required this.enableSuggestions,
    this.hint,
    this.trailingLabel,
    this.trailing,
    this.obscureText = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.onSubmitted,
  });

  final String semanticLabel;
  final String label;
  final String? hint;
  final IconData icon;
  final TextEditingController controller;
  final String placeholder;
  final String? Function(String?) validator;
  final bool enabled;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final TextCapitalization textCapitalization;
  final Iterable<String> autofillHints;
  final bool enableSuggestions;
  final VoidCallback? onSubmitted;
  final Widget? trailingLabel;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.isDark(context);
    final textStyle = AppTextStyles.callout(context).copyWith(height: 1.3);
    final hintStyle = AppTextStyles.callout(
      context,
      color: AppColors.textTertiary,
    ).copyWith(height: 1.3);
    return FormField<String>(
      initialValue: controller.text,
      // Selalu menilai isi controller (bisa dikosongkan lewat kode).
      validator: (_) => validator(controller.text),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      builder: (state) {
        final error = state.errorText;
        final danger = AppColors.danger.resolveFrom(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 2,
                children: [
                  ExcludeSemantics(
                    child: Text(
                      label,
                      style: AppTextStyles.labelMd(
                        context,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  if (hint != null)
                    Text(
                      hint!,
                      style: AppTextStyles.caption1(
                        context,
                        emphasized: true,
                        color: AppColors.tint,
                      ),
                    ),
                  ?trailingLabel,
                ],
              ),
            ),
            Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.only(left: 14, right: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh
                    .resolveFrom(context)
                    .withValues(alpha: dark ? 0.5 : 1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: error == null
                      ? AppColors.separator.resolveFrom(context)
                      : danger,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: AppColors.textTertiary.resolveFrom(context),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Semantics(
                      label: semanticLabel,
                      child: CupertinoTextField(
                        controller: controller,
                        placeholder: placeholder,
                        enabled: enabled,
                        obscureText: obscureText,
                        keyboardType: keyboardType,
                        textInputAction: textInputAction,
                        textCapitalization: textCapitalization,
                        autofillHints: autofillHints,
                        autocorrect: false,
                        enableSuggestions: enableSuggestions,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: null,
                        style: textStyle,
                        placeholderStyle: hintStyle,
                        onChanged: state.didChange,
                        onSubmitted: onSubmitted == null
                            ? null
                            : (_) => onSubmitted!(),
                      ),
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 2),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    error,
                    style: AppTextStyles.caption1(
                      context,
                      color: AppColors.danger,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final line = Expanded(
      child: SizedBox(
        height: 1,
        child: ColoredBox(color: AppColors.separator.resolveFrom(context)),
      ),
    );
    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            AuthStrings.or.toUpperCase(),
            style: AppTextStyles.caption2(
              context,
              emphasized: true,
              color: AppColors.textTertiary,
            ).copyWith(letterSpacing: 1.5),
          ),
        ),
        line,
      ],
    );
  }
}

/// Tombol "Lanjutkan dengan Google". Masuk lewat Google belum tersambung
/// (butuh proyek Google Cloud), jadi tombol ini belum berfungsi.
class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: AuthStrings.continueWithGoogle,
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh
              .resolveFrom(context)
              .withValues(alpha: AppColors.isDark(context) ? 0.5 : 1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.separator.resolveFrom(context)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _GoogleG(),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                AuthStrings.continueWithGoogle,
                style: AppTextStyles.labelMd(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Huruf "G" Google dari empat warna merek (tanpa aset gambar).
class _GoogleG extends StatelessWidget {
  const _GoogleG();

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (r) => const LinearGradient(
        colors: [
          Color(0xFF4285F4),
          Color(0xFF34A853),
          Color(0xFFFBBC05),
          Color(0xFFEA4335),
        ],
        stops: [0.0, 0.4, 0.65, 1.0],
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
      ).createShader(r),
      blendMode: BlendMode.srcIn,
      child: const Text(
        'G',
        style: TextStyle(
          fontFamily: AppTextStyles.fontDisplay,
          fontWeight: FontWeight.w800,
          fontSize: 18,
          height: 1,
          color: Color(0xFFFFFFFF),
        ),
      ),
    );
  }
}

/// Catatan persetujuan di dasar halaman. Tautan belum membuka halaman
/// (dokumen hukum belum ada), hanya ditandai garis bawah.
class _TermsFooter extends StatelessWidget {
  const _TermsFooter();

  @override
  Widget build(BuildContext context) {
    final base = AppTextStyles.caption1(
      context,
      color: AppColors.textTertiary,
    ).copyWith(height: 1.5);
    final link = base.copyWith(decoration: TextDecoration.underline);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text.rich(
        TextSpan(
          style: base,
          children: [
            const TextSpan(text: AuthStrings.termsPrefix),
            TextSpan(text: AuthStrings.termsOfService, style: link),
            const TextSpan(text: AuthStrings.termsAnd),
            TextSpan(text: AuthStrings.privacyPolicy, style: link),
            const TextSpan(text: AuthStrings.termsSuffix),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// Pesan status dengan ikon Obsidian Dark Glass.
class _MessageRow extends StatelessWidget {
  const _MessageRow({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isError
              ? AppColors.danger.resolveFrom(context).withValues(alpha: 0.15)
              : AppColors.tint.resolveFrom(context).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isError
                ? AppColors.danger.resolveFrom(context).withValues(alpha: 0.40)
                : AppColors.tint.resolveFrom(context).withValues(alpha: 0.40),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isError ? Symbols.error : Symbols.info,
              size: 18,
              color: isError
                  ? AppColors.danger.resolveFrom(context)
                  : AppColors.tint.resolveFrom(context),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  height: 1.3,
                  color: isError
                      ? AppColors.danger.resolveFrom(context)
                      : AppColors.tint.resolveFrom(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
