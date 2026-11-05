import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/auth_providers.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_validators.dart';
import 'auth_strings.dart';

enum _Mode { signIn, signUp }

/// Masuk dan daftar dalam satu halaman dengan identitas Apple Hero Branding
/// dan form bergaya iOS Inset Grouped. Setelah berhasil, auth gate
/// (currentUserIdProvider) memindahkan ke tab lewat redirect router.
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
  String? _message;
  bool _messageIsError = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  String? _validate(AuthFieldError? e) =>
      e == null ? null : AuthStrings.fieldError(e);

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    final repo = ref.read(authRepositoryProvider);
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (_mode == _Mode.signIn) {
        await repo.signIn(email: _email.text, password: _password.text);
      } else {
        final outcome = await repo.signUp(
          email: _email.text,
          password: _password.text,
          displayName: _name.text,
        );
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
      if (mounted) {
        setState(() {
          _message = AuthStrings.failure(f.kind);
          _messageIsError = true;
        });
      }
    } catch (_) {
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

  void _setMode(_Mode? mode) {
    if (mode == null || mode == _mode) return;
    setState(() {
      _mode = mode;
      _message = null;
    });
    _formKey.currentState?.reset();
  }

  @override
  Widget build(BuildContext context) {
    final signUp = _mode == _Mode.signUp;
    return CupertinoPageScaffold(
      backgroundColor: AppColors.groupedBackground,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: CupertinoColors.black.withValues(alpha: 0.08),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.asset(
                        'assets/branding/app_icon.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Semantics(
                  header: true,
                  child: Text(
                    AuthStrings.title,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.largeTitle(context, emphasized: true),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  AuthStrings.subtitle,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.subhead(
                    context,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoSlidingSegmentedControl<_Mode>(
                    groupValue: _mode,
                    onValueChanged: _busy ? (_) {} : _setMode,
                    children: {
                      _Mode.signIn: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          AuthStrings.modeSignIn,
                          style: AppTextStyles.subhead(context),
                        ),
                      ),
                      _Mode.signUp: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          AuthStrings.modeSignUp,
                          style: AppTextStyles.subhead(context),
                        ),
                      ),
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Form(
                  key: _formKey,
                  child: CupertinoFormSection.insetGrouped(
                    margin: EdgeInsets.zero,
                    children: [
                      if (signUp)
                        Semantics(
                          label: AuthStrings.nameLabel,
                          child: CupertinoTextFormFieldRow(
                            controller: _name,
                            placeholder: AuthStrings.namePlaceholder,
                            enabled: !_busy,
                            autocorrect: false,
                            enableSuggestions: true,
                            textInputAction: TextInputAction.next,
                            textCapitalization: TextCapitalization.words,
                            autofillHints: const [AutofillHints.name],
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            validator: (v) =>
                                _validate(AuthValidators.displayName(v)),
                          ),
                        ),
                      Semantics(
                        label: AuthStrings.emailLabel,
                        child: CupertinoTextFormFieldRow(
                          controller: _email,
                          placeholder: AuthStrings.emailPlaceholder,
                          enabled: !_busy,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          enableSuggestions: true,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          validator: (v) => _validate(AuthValidators.email(v)),
                        ),
                      ),
                      Semantics(
                        label: AuthStrings.passwordLabel,
                        child: CupertinoTextFormFieldRow(
                          controller: _password,
                          placeholder: AuthStrings.passwordPlaceholder,
                          enabled: !_busy,
                          obscureText: true,
                          autocorrect: false,
                          enableSuggestions: false,
                          textInputAction: TextInputAction.done,
                          autofillHints: [
                            signUp
                                ? AutofillHints.newPassword
                                : AutofillHints.password,
                          ],
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          validator: (v) =>
                              _validate(AuthValidators.password(v)),
                          onFieldSubmitted: (_) => _submit(),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_message != null) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _MessageRow(
                      message: _message!,
                      isError: _messageIsError,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                PrimaryButton(
                  label: signUp
                      ? AuthStrings.submitSignUp
                      : AuthStrings.submitSignIn,
                  busyLabel: AuthStrings.processing,
                  busy: _busy,
                  onPressed: _submit,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pesan status dengan ikon, supaya tidak hanya mengandalkan warna.
class _MessageRow extends StatelessWidget {
  const _MessageRow({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError
                ? CupertinoIcons.exclamationmark_circle_fill
                : CupertinoIcons.info_circle_fill,
            size: 20,
            color: CupertinoDynamicColor.resolve(
              isError ? AppColors.danger : AppColors.tint,
              context,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: AppTextStyles.subhead(context))),
        ],
      ),
    );
  }
}
