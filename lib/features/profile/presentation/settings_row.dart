import 'package:flutter/cupertino.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';

/// Baris pengaturan di dalam kartu bergaya grouped: label, keterangan opsional,
/// dan chevron. Area sentuh minimal 44 pt.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.label,
    required this.onPressed,
    this.subtitle,
    this.destructive = false,
  });

  final String label;
  final String? subtitle;
  final bool destructive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CupertinoDynamicColor.resolve(
          AppColors.groupedItemBackground,
          context,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Semantics(
        button: true,
        label: subtitle == null ? label : '$label, $subtitle',
        excludeSemantics: true,
        onTap: onPressed,
        child: CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          minimumSize: const Size.fromHeight(44),
          alignment: AlignmentDirectional.centerStart,
          onPressed: onPressed,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTextStyles.body(
                        context,
                        color: destructive ? AppColors.danger : AppColors.tint,
                      ),
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
    );
  }
}
