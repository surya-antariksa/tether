import 'package:flutter/cupertino.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/design_widgets.dart';
import '../../../core/widgets/glass_card.dart';

/// Baris pengaturan berbentuk kartu: ikon dalam kotak, label, keterangan
/// opsional, dan chevron. Area sentuh minimal 44 pt. [destructive] = kartu
/// bernuansa merah (hapus akun).
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.label,
    required this.onPressed,
    this.subtitle,
    this.destructive = false,
    this.icon,
  });

  final String label;
  final String? subtitle;
  final bool destructive;
  final VoidCallback onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final danger = AppColors.danger.resolveFrom(context);
    final accent = destructive ? AppColors.danger : AppColors.tint;
    final row = Row(
      children: [
        if (icon != null) ...[
          IconTile(icon: icon!, color: accent, size: 40, iconSize: 22),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.body(
                  context,
                  emphasized: true,
                  color: destructive ? AppColors.danger : AppColors.textPrimary,
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
          Symbols.chevron_right,
          size: 20,
          color: destructive
              ? danger
              : AppColors.textSecondary.resolveFrom(context),
        ),
      ],
    );
    return Semantics(
      button: true,
      label: subtitle == null ? label : '$label, $subtitle',
      excludeSemantics: true,
      onTap: onPressed,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: destructive
              ? Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: danger.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: danger.withValues(alpha: 0.28)),
                  ),
                  child: row,
                )
              : GlassCard(padding: const EdgeInsets.all(14), child: row),
        ),
      ),
    );
  }
}
