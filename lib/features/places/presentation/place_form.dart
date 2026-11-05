import 'package:flutter/cupertino.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../domain/place.dart';
import 'place_strings.dart';

/// Isian nama dan slider radius, dipakai di pemilih titik dan lembar ubah.
/// Keadaan (controller, radius, galat) dipegang pemanggil.
class PlaceForm extends StatelessWidget {
  const PlaceForm({
    super.key,
    required this.controller,
    required this.radiusM,
    required this.onRadiusChanged,
    required this.onNameChanged,
    required this.onSubmitted,
    this.enabled = true,
    this.error,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final int radiusM;
  final ValueChanged<int> onRadiusChanged;
  final VoidCallback onNameChanged;
  final VoidCallback onSubmitted;
  final bool enabled;
  final String? error;
  final bool autofocus;

  static const _divisions =
      (PlaceLimits.maxRadiusM - PlaceLimits.minRadiusM) ~/
      PlaceLimits.radiusStepM;

  int _step(int direction) => (radiusM + direction * PlaceLimits.radiusStepM)
      .clamp(PlaceLimits.minRadiusM, PlaceLimits.maxRadiusM);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: PlaceStrings.nameLabel,
          textField: true,
          child: CupertinoTextField(
            controller: controller,
            autofocus: autofocus,
            enabled: enabled,
            placeholder: PlaceStrings.namePlaceholder,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            padding: const EdgeInsets.all(14),
            onChanged: (_) => onNameChanged(),
            onSubmitted: (_) => onSubmitted(),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                PlaceStrings.radiusLabel,
                style: AppTextStyles.body(context),
              ),
            ),
            ExcludeSemantics(
              child: Text(
                PlaceStrings.radiusValue(radiusM),
                style: AppTextStyles.body(
                  context,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        // Node geser bawaan hanya membacakan persen: ganti dengan meter.
        Semantics(
          slider: true,
          enabled: enabled,
          label: PlaceStrings.radiusLabel,
          value: PlaceStrings.radiusSemantic(radiusM),
          increasedValue: PlaceStrings.radiusSemantic(_step(1)),
          decreasedValue: PlaceStrings.radiusSemantic(_step(-1)),
          onIncrease: enabled ? () => onRadiusChanged(_step(1)) : null,
          onDecrease: enabled ? () => onRadiusChanged(_step(-1)) : null,
          excludeSemantics: true,
          child: SizedBox(
            height: 44,
            child: CupertinoSlider(
              value: radiusM.toDouble(),
              min: PlaceLimits.minRadiusM.toDouble(),
              max: PlaceLimits.maxRadiusM.toDouble(),
              divisions: _divisions,
              onChanged: enabled ? (v) => onRadiusChanged(v.round()) : null,
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Semantics(
              liveRegion: true,
              child: Text(
                error!,
                style: AppTextStyles.footnote(context, color: AppColors.danger),
              ),
            ),
          ),
      ],
    );
  }
}
