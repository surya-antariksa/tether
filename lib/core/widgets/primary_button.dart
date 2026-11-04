import 'package:flutter/cupertino.dart';

import '../../app/theme/app_text_styles.dart';

/// Tombol utama (peran primary): latar tint, teks kontras. Saat [busy],
/// menampilkan ikon aktivitas dan tidak bisa ditekan.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.busyLabel,
    required this.onPressed,
    this.busy = false,
  });

  final String label;

  /// Label semantik saat memproses (untuk pembaca layar).
  final String busyLabel;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final onPrimary = CupertinoTheme.of(context).primaryContrastingColor;
    return Semantics(
      button: true,
      enabled: !busy && onPressed != null,
      label: busy ? busyLabel : label,
      excludeSemantics: true,
      child: CupertinoButton.filled(
        minimumSize: const Size(44, 44),
        onPressed: busy ? null : onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy) ...[
              CupertinoActivityIndicator(color: onPrimary),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: AppTextStyles.body(
                  context,
                  emphasized: true,
                  color: onPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
