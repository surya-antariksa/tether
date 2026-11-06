import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../domain/map_style.dart';
import 'map_strings.dart';

/// Membuka lembar pemilih tipe peta; mengembalikan pilihan atau null bila batal.
Future<MapStyle?> showMapTypeSheet(BuildContext context, MapStyle current) =>
    showCupertinoModalPopup<MapStyle>(
      context: context,
      barrierColor: const Color(0xA6000000),
      builder: (_) => MapTypeSheet(current: current),
    );

/// Lembar kaca "Pilih tipe peta": empat kartu dengan pratinjau mini, kartu
/// terpilih bertanda AKTIF dan centang, tombol Batal di bawah.
class MapTypeSheet extends StatelessWidget {
  const MapTypeSheet({super.key, required this.current});

  final MapStyle current;

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.isDark(context);
    final solid = MediaQuery.highContrastOf(context);
    const radius = BorderRadius.all(Radius.circular(32));
    Widget card = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: dark
            ? AppColors.glassFill
                  .resolveFrom(context)
                  .withValues(alpha: solid ? 1 : 0.94)
            : AppColors.background.resolveFrom(context),
        borderRadius: radius,
        border: Border.all(color: AppColors.glassBorder.resolveFrom(context)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                ExcludeSemantics(
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.tint
                          .resolveFrom(context)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.tint
                            .resolveFrom(context)
                            .withValues(alpha: 0.3),
                      ),
                    ),
                    child: Icon(
                      Symbols.layers,
                      size: 16,
                      color: AppColors.tint.resolveFrom(context),
                    ),
                  ),
                ),
                Semantics(
                  header: true,
                  child: Text(
                    MapStrings.mapTypeTitle,
                    style: AppTextStyles.headline(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            MapStrings.mapTypeSubtitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.caption1(
              context,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          for (final o in _options) ...[
            _Option(
              option: o,
              selected: o.style == current,
              onTap: () => Navigator.of(context).pop(o.style),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 2),
          Semantics(
            button: true,
            label: MapStrings.cancel,
            excludeSemantics: true,
            onTap: () => Navigator.of(context).pop(),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                constraints: const BoxConstraints(minHeight: 52),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh.resolveFrom(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.separator.resolveFrom(context),
                  ),
                ),
                child: Text(
                  MapStrings.cancel,
                  style: AppTextStyles.body(context, emphasized: true),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    if (dark && !solid) {
      card = ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: card,
        ),
      );
    }
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Semantics(
              scopesRoute: true,
              explicitChildNodes: true,
              label: MapStrings.mapTypeTitle,
              child: SingleChildScrollView(child: card),
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionData {
  const _OptionData(this.style, this.label, this.description);

  final MapStyle style;
  final String label;
  final String description;
}

const _options = [
  _OptionData(
    MapStyle.auto,
    MapStrings.mapTypeAuto,
    MapStrings.mapTypeAutoDesc,
  ),
  _OptionData(
    MapStyle.standard,
    MapStrings.mapTypeStandard,
    MapStrings.mapTypeStandardDesc,
  ),
  _OptionData(
    MapStyle.dark,
    MapStrings.mapTypeDark,
    MapStrings.mapTypeDarkDesc,
  ),
  _OptionData(
    MapStyle.topo,
    MapStrings.mapTypeTopo,
    MapStrings.mapTypeTopoDesc,
  ),
];

class _Option extends StatelessWidget {
  const _Option({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _OptionData option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.isDark(context);
    final tint = AppColors.tint.resolveFrom(context);
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: '${option.label}, ${option.description}',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            // Isi opak: bayangan cahaya tidak boleh tembus ke dalam kartu.
            color: selected
                ? Color.alphaBlend(
                    tint.withValues(alpha: dark ? 0.12 : 0.07),
                    AppColors.groupedItemBackground.resolveFrom(context),
                  )
                : AppColors.groupedItemBackground.resolveFrom(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? tint : AppColors.separator.resolveFrom(context),
              width: selected ? 1.5 : 1,
            ),
            boxShadow: selected && dark
                ? [
                    BoxShadow(
                      color: tint.withValues(alpha: 0.25),
                      blurRadius: 20,
                      spreadRadius: -4,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              _Thumb(style: option.style),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      children: [
                        Text(
                          option.label,
                          style: AppTextStyles.callout(
                            context,
                            emphasized: true,
                            color: selected
                                ? AppColors.tint
                                : AppColors.textPrimary,
                          ),
                        ),
                        if (selected)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: tint.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: tint.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Text(
                              MapStrings.mapTypeActive.toUpperCase(),
                              style: AppTextStyles.caption2(
                                context,
                                emphasized: true,
                                color: AppColors.tint,
                              ),
                            ),
                          ),
                      ],
                    ),
                    Text(
                      option.description,
                      style: AppTextStyles.caption1(
                        context,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (selected)
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: tint,
                    boxShadow: dark
                        ? [
                            BoxShadow(
                              color: tint.withValues(alpha: 0.6),
                              blurRadius: 10,
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    Symbols.check,
                    size: 16,
                    weight: 700,
                    color: AppColors.onTint.resolveFrom(context),
                  ),
                )
              else
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.textTertiary.resolveFrom(context),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pratinjau mini 48x48 tiap tipe peta.
class _Thumb extends StatelessWidget {
  const _Thumb({required this.style});

  final MapStyle style;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 48,
          height: 48,
          child: CustomPaint(painter: _ThumbPainter(style)),
        ),
      ),
    );
  }
}

class _ThumbPainter extends CustomPainter {
  const _ThumbPainter(this.style);

  final MapStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    Paint line(Color c, double sw) => Paint()
      ..color = c
      ..strokeWidth = sw
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    switch (style) {
      case MapStyle.auto:
        canvas.drawRect(
          Offset.zero & size,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E293B), Color(0xFF07090E), Color(0xFF083344)],
            ).createShader(Offset.zero & size),
        );
        final grid = line(const Color(0x9900F2FE), 0.8);
        for (final f in [1 / 3, 2 / 3]) {
          canvas.drawLine(Offset(0, h * f), Offset(w, h * f), grid);
          canvas.drawLine(Offset(w * f, 0), Offset(w * f, h), grid);
        }
        canvas.drawCircle(
          Offset(w / 2, h / 2),
          3,
          Paint()..color = const Color(0xFF00F2FE),
        );
      case MapStyle.standard:
        canvas.drawRect(
          Offset.zero & size,
          Paint()..color = const Color(0xFFE2E8F0),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.12, h * 0.12, w * 0.21, h * 0.25),
            const Radius.circular(2),
          ),
          Paint()..color = const Color(0xFFCBD5E1),
        );
        canvas.drawPath(
          Path()
            ..moveTo(0, h * 0.5)
            ..quadraticBezierTo(w * 0.5, h * 0.42, w, h * 0.5),
          line(const Color(0xFFF59E0B), 3),
        );
        canvas.drawLine(
          Offset(w * 0.42, 0),
          Offset(w * 0.58, h),
          line(const Color(0xFF38BDF8), 2.5),
        );
      case MapStyle.dark:
        canvas.drawRect(
          Offset.zero & size,
          Paint()..color = const Color(0xFF090D14),
        );
        final road = line(const Color(0xFF1F293D), 2);
        canvas.drawLine(Offset(0, h * 0.375), Offset(w, h * 0.375), road);
        canvas.drawLine(Offset(0, h * 0.71), Offset(w, h * 0.71), road);
        final road2 = line(const Color(0xFF172033), 2);
        canvas.drawLine(Offset(w * 0.29, 0), Offset(w * 0.29, h), road2);
        canvas.drawLine(Offset(w * 0.71, 0), Offset(w * 0.71, h), road2);
        canvas.drawCircle(
          Offset(w * 0.58, h * 0.46),
          2.5,
          Paint()..color = const Color(0xFF38BDF8),
        );
      case MapStyle.topo:
        canvas.drawRect(
          Offset.zero & size,
          Paint()..color = const Color(0xFF0F172A),
        );
        for (final (i, y) in [0.8, 0.54, 0.29, 0.06].indexed) {
          canvas.drawPath(
            Path()
              ..moveTo(-w * 0.1, h * y)
              ..cubicTo(
                w * 0.2,
                h * (y - 0.12),
                w * 0.55,
                h * (y + 0.12),
                w * 1.1,
                h * (y - 0.1),
              ),
            line(Color.fromRGBO(16, 185, 129, 0.75 - i * 0.12), 1.2),
          );
        }
    }
  }

  @override
  bool shouldRepaint(_ThumbPainter old) => old.style != style;
}
