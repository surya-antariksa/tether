import 'package:flutter/cupertino.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'app_strings.dart';
import 'theme/app_colors.dart';
import 'theme/app_text_styles.dart';

/// Ditampilkan bila konfigurasi Supabase belum diberikan (tidak crash).
class ConfigMissingPage extends StatelessWidget {
  const ConfigMissingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.groupedBackground,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Icon(
                  Symbols.warning,
                  size: 40,
                  color: CupertinoDynamicColor.resolve(
                    AppColors.warning,
                    context,
                  ),
                ),
                const SizedBox(height: 16),
                Semantics(
                  header: true,
                  child: Text(
                    AppStrings.configMissingTitle,
                    style: AppTextStyles.title1(context, emphasized: true),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  AppStrings.configMissingBody,
                  style: AppTextStyles.body(context),
                ),
                const SizedBox(height: 16),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: CupertinoDynamicColor.resolve(
                      AppColors.groupedItemBackground,
                      context,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      AppStrings.configMissingExample,
                      style: AppTextStyles.footnote(
                        context,
                      ).copyWith(fontFamily: 'monospace'),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  AppStrings.configMissingHint,
                  style: AppTextStyles.footnote(
                    context,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
