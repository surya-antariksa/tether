import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/primary_button.dart';
import '../domain/circle.dart';
import 'circle_strings.dart';

/// Menampilkan kode undangan dalam sheet modal.
Future<void> showInviteSheet(BuildContext context, CircleInvite invite) {
  return showCupertinoModalPopup<void>(
    context: context,
    builder: (_) => InviteSheet(invite: invite),
  );
}

class InviteSheet extends StatefulWidget {
  const InviteSheet({super.key, required this.invite});

  final CircleInvite invite;

  @override
  State<InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<InviteSheet> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.invite.code));
    if (mounted) setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.invite.code;
    return DefaultTextStyle(
      style: CupertinoTheme.of(context).textTheme.textStyle,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: CupertinoDynamicColor.resolve(
                AppColors.groupedBackground,
                context,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        CircleStrings.inviteTitle,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.headline(context),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Semantics(
                      label: CircleStrings.inviteCodeLabel(code),
                      excludeSemantics: true,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          code,
                          style: AppTextStyles.largeTitle(
                            context,
                            emphasized: true,
                          ).copyWith(letterSpacing: 8, fontFamily: 'monospace'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      CircleStrings.inviteExpires(
                        CircleStrings.formatWhen(widget.invite.expiresAt),
                      ),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.subhead(context),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      CircleStrings.inviteNote,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.footnote(
                        context,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      label: _copied
                          ? CircleStrings.copied
                          : CircleStrings.copy,
                      busyLabel: CircleStrings.copy,
                      onPressed: _copy,
                    ),
                    const SizedBox(height: 8),
                    CupertinoButton(
                      minimumSize: const Size.fromHeight(44),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(CircleStrings.done),
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
