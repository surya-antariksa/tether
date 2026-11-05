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

/// Masuk dan daftar dalam satu halaman. Setelah berhasil, auth gate
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

  Widget _field({
    required String label,
    required TextEditingController controller,
    required String placeholder,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    bool obscure = false,
    TextInputAction action = TextInputAction.next,
    Iterable<String>? autofillHints,
    TextCapitalization capitalization = TextCapitalization.none,
    VoidCallback? onSubmit,
  }) {
    return CupertinoFormSection.insetGrouped(
      margin: const EdgeInsetsDirectional.fromSTEB(0, 0, 0, 8),
      header: Text(label),
      children: [
        Semantics(
          label: label,
          child: CupertinoTextFormFieldRow(
            controller: controller,
            placeholder: placeholder,
            enabled: !_busy,
            keyboardType: keyboardType,
            obscureText: obscure,
            autocorrect: false,
            enableSuggestions: !obscure,
            textInputAction: action,
            textCapitalization: capitalization,
            autofillHints: autofillHints,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: validator,
            onFieldSubmitted: onSubmit == null ? null : (_) => onSubmit(),
          ),
        ),
      ],
    );
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    AuthStrings.title,
                    style: AppTextStyles.largeTitle(context, emphasized: true),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AuthStrings.subtitle,
                  style: AppTextStyles.subhead(
                    context,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                CupertinoSlidingSegmentedControl<_Mode>(
                  groupValue: _mode,
                  onValueChanged: _busy ? (_) {} : _setMode,
                  children: {
                    _Mode.signIn: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(AuthStrings.modeSignIn),
                    ),
                    _Mode.signUp: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(AuthStrings.modeSignUp),
                    ),
                  },
                ),
                const SizedBox(height: 16),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (signUp)
                        _field(
                          label: AuthStrings.nameLabel,
                          controller: _name,
                          placeholder: AuthStrings.namePlaceholder,
                          validator: (v) =>
                              _validate(AuthValidators.displayName(v)),
                          autofillHints: const [AutofillHints.name],
                          capitalization: TextCapitalization.words,
                        ),
                      _field(
                        label: AuthStrings.emailLabel,
                        controller: _email,
                        placeholder: AuthStrings.emailPlaceholder,
                        validator: (v) => _validate(AuthValidators.email(v)),
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                      ),
                      _field(
                        label: AuthStrings.passwordLabel,
                        controller: _password,
                        placeholder: AuthStrings.passwordPlaceholder,
                        validator: (v) => _validate(AuthValidators.password(v)),
                        obscure: true,
                        action: TextInputAction.done,
                        autofillHints: [
                          signUp
                              ? AutofillHints.newPassword
                              : AutofillHints.password,
                        ],
                        onSubmit: _submit,
                      ),
                    ],
                  ),
                ),
                if (_message != null) ...[
                  const SizedBox(height: 8),
                  _MessageRow(message: _message!, isError: _messageIsError),
                ],
                const SizedBox(height: 16),
                PrimaryButton(
                  label: signUp
                      ? AuthStrings.submitSignUp
                      : AuthStrings.submitSignIn,
                  busyLabel: AuthStrings.processing,
                  busy: _busy,
                  onPressed: _submit,
                ),
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
