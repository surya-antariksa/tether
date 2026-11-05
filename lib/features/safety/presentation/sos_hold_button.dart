import 'package:flutter/cupertino.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_text_styles.dart';
import '../data/safety_providers.dart';
import 'safety_strings.dart';

/// Tombol SOS yang harus ditahan [holdDuration] (bawaan 3 detik) dengan
/// progres terlihat dan haptic tiap detik. Melepas sebelum selesai
/// membatalkan tanpa efek. Setelah selesai memanggil [onActivated], yang
/// seharusnya memulai hitung mundur 5 detik (tidak langsung mengirim).
///
/// Aksesibilitas: aksi semantik "Mulai SOS" dan aksi tekan-lama pembaca layar
/// memanggil [onActivated] tanpa menahan; hitung mundur tetap berlaku.
/// Reduce Motion: progres naik per detik (sepertiga), bukan mengalir.
class SosHoldButton extends ConsumerStatefulWidget {
  const SosHoldButton({
    super.key,
    required this.onActivated,
    this.holdDuration = const Duration(seconds: 3),
  });

  final VoidCallback onActivated;
  final Duration holdDuration;

  @override
  ConsumerState<SosHoldButton> createState() => _SosHoldButtonState();
}

class _SosHoldButtonState extends ConsumerState<SosHoldButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int _lastStep = 0;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
            vsync: this,
            duration: widget.holdDuration,
            // Tanpa ini, Reduce Motion memadatkan 3 detik menjadi ~150 ms dan
            // SOS terpicu hampir seketika.
            animationBehavior: AnimationBehavior.preserve,
          )
          ..addListener(_onProgress)
          ..addStatusListener(_onStatus);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onProgress() {
    final step = (_controller.value * 3).floor();
    if (step > _lastStep && step < 3) {
      ref.read(sosHapticsProvider).holdTick();
    }
    _lastStep = step;
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _controller.value = 0;
      _lastStep = 0;
      widget.onActivated();
    }
  }

  void _start() {
    _lastStep = 0;
    _controller.forward(from: 0);
  }

  void _release() {
    if (_controller.isAnimating) {
      _controller.value = 0;
      _lastStep = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final red = CupertinoColors.systemRed.resolveFrom(context);
    final dark = Color.alphaBlend(const Color(0x40000000), red);
    return Semantics(
      container: true,
      button: true,
      label: SafetyStrings.holdLabel,
      hint: SafetyStrings.holdHint,
      onLongPress: widget.onActivated,
      customSemanticsActions: {
        const CustomSemanticsAction(label: SafetyStrings.startActionLabel):
            widget.onActivated,
      },
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _start(),
        onTapUp: (_) => _release(),
        onTapCancel: _release,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final raw = _controller.value;
              final progress = reduce ? (raw * 3).floor() / 3 : raw;
              final holding = raw > 0;
              return ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: red,
                    boxShadow: [
                      BoxShadow(
                        color: red.withValues(alpha: holding ? 0.45 : 0.25),
                        blurRadius: holding ? 18 : 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: FractionallySizedBox(
                            widthFactor: progress,
                            heightFactor: 1,
                            child: ColoredBox(
                              key: const ValueKey('sos-hold-progress'),
                              color: dark,
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              holding
                                  ? CupertinoIcons.exclamationmark_triangle_fill
                                  : CupertinoIcons.exclamationmark_shield_fill,
                              color: CupertinoColors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                holding
                                    ? SafetyStrings.holdActive
                                    : SafetyStrings.holdIdle,
                                textAlign: TextAlign.center,
                                style: AppTextStyles.body(
                                  context,
                                  emphasized: true,
                                  color: CupertinoColors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
