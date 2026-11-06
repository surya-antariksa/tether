import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/member_avatar.dart';
import '../../../core/widgets/primary_button.dart';
import '../../circle/data/circle_providers.dart';
import '../../profile/data/profile_providers.dart';
import '../data/auth_providers.dart';
import 'auth_strings.dart';

/// Pop-up "Verifikasi Sesi Akun" yang tampil SEGERA saat Masuk/Daftar ditekan
/// (tombol sendiri tidak berputar). Fase 1: cincin berputar dan tiga langkah
/// yang tercentang satu per satu sesuai data nyata (kredensial, profil,
/// Circle). Fase 2 (sesudah masuk): akun, jumlah Circle, Lanjutkan ke Peta
/// dan Ganti Akun. Animasi hanya berjalan selama memverifikasi.
class SessionVerifyDialog extends ConsumerStatefulWidget {
  const SessionVerifyDialog({
    super.key,
    required this.onContinue,
    required this.onSwitch,
  });

  final VoidCallback onContinue;
  final VoidCallback onSwitch;

  @override
  ConsumerState<SessionVerifyDialog> createState() =>
      _SessionVerifyDialogState();
}

class _SessionVerifyDialogState extends ConsumerState<SessionVerifyDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  bool _switching = false;

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  void _sync(bool verifying, bool reduceMotion) {
    if (verifying && !reduceMotion) {
      if (!_spin.isAnimating) _spin.repeat();
    } else if (_spin.isAnimating) {
      _spin.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(currentUserIdProvider) != null;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final dark = AppColors.isDark(context);
    final tint = AppColors.tint.resolveFrom(context);
    final success = AppColors.success.resolveFrom(context);
    // Data hanya diminta sesudah masuk (provider ini butuh sesi).
    final profile = signedIn ? ref.watch(ownProfileProvider) : null;
    final circles = signedIn ? ref.watch(myCirclesProvider) : null;
    final profileDone = profile != null && !profile.isLoading;
    final circlesDone = circles != null && !circles.isLoading;
    _sync(!signedIn, reduce);

    final circleCount = circles?.value?.length;
    const radius = BorderRadius.all(Radius.circular(32));
    final solid = MediaQuery.highContrastOf(context);
    Widget card = Container(
      padding: const EdgeInsets.all(24),
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
            child: ExcludeSemantics(
              child: AnimatedBuilder(
                animation: _spin,
                builder: (context, _) => CustomPaint(
                  size: const Size(104, 104),
                  painter: _RingPainter(
                    t: _spin.value,
                    color: tint,
                    doneColor: success,
                    done: signedIn,
                    glow: dark,
                  ),
                  child: SizedBox(
                    width: 104,
                    height: 104,
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        child: Icon(
                          signedIn ? Symbols.verified_user : Symbols.lock,
                          key: ValueKey(signedIn),
                          size: 32,
                          fill: 1,
                          color: signedIn ? success : tint,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Semantics(
              liveRegion: true,
              child: _StatusPill(
                text: signedIn
                    ? AuthStrings.confirmReady
                    : AuthStrings.verifying,
                color: signedIn
                    ? success
                    : AppColors.warning.resolveFrom(context),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Semantics(
            header: true,
            child: Text(
              AuthStrings.confirmTitle,
              textAlign: TextAlign.center,
              style: AppTextStyles.title2(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AuthStrings.confirmSubtitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.footnote(
              context,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          _Step(
            label: AuthStrings.stepCredentials,
            done: signedIn,
            spin: _spin,
            active: true,
          ),
          _Step(
            label: AuthStrings.stepProfile,
            done: profileDone,
            spin: _spin,
            active: signedIn,
          ),
          _Step(
            label: AuthStrings.stepCircles,
            done: circlesDone,
            spin: _spin,
            active: signedIn,
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: signedIn
                ? Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _AccountRow(
                          name: profile?.value?.displayName,
                          email: profile?.value?.email,
                          colorHex: profile?.value?.color,
                          circleLabel: circleCount == null
                              ? null
                              : (circleCount == 0
                                    ? AuthStrings.confirmNoCircle
                                    : AuthStrings.confirmCircles(circleCount)),
                        ),
                        const SizedBox(height: 16),
                        PrimaryButton(
                          label: AuthStrings.confirmContinue,
                          busyLabel: AuthStrings.processing,
                          trailingIcon: Symbols.arrow_forward,
                          onPressed: _switching ? null : widget.onContinue,
                        ),
                        const SizedBox(height: 10),
                        Semantics(
                          button: true,
                          label: AuthStrings.confirmSwitch,
                          excludeSemantics: true,
                          onTap: _switching ? null : _doSwitch,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _switching ? null : _doSwitch,
                            child: Container(
                              constraints: const BoxConstraints(minHeight: 48),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceHigh.resolveFrom(
                                  context,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppColors.separator.resolveFrom(
                                    context,
                                  ),
                                ),
                              ),
                              child: Text(
                                AuthStrings.confirmSwitch,
                                textAlign: TextAlign.center,
                                style: AppTextStyles.labelMd(
                                  context,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
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
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Semantics(
            scopesRoute: true,
            explicitChildNodes: true,
            label: AuthStrings.confirmTitle,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                boxShadow: [
                  BoxShadow(
                    color: dark
                        ? tint.withValues(alpha: 0.18)
                        : const Color(0x33000000),
                    blurRadius: 48,
                    spreadRadius: -8,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: card,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _doSwitch() async {
    setState(() => _switching = true);
    widget.onSwitch();
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh.resolveFrom(context),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.separator.resolveFrom(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: AppTextStyles.caption1(
                context,
                emphasized: true,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Satu langkah verifikasi: putaran kecil selagi berjalan, centang saat selesai.
class _Step extends StatelessWidget {
  const _Step({
    required this.label,
    required this.done,
    required this.spin,
    required this.active,
  });

  final String label;
  final bool done;
  final Animation<double> spin;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final tint = AppColors.tint.resolveFrom(context);
    final success = AppColors.success.resolveFrom(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: done
                  ? Icon(
                      Symbols.check_circle,
                      key: const ValueKey('done'),
                      size: 20,
                      fill: 1,
                      color: success,
                    )
                  : (active
                        ? AnimatedBuilder(
                            key: const ValueKey('spin'),
                            animation: spin,
                            builder: (context, _) => CustomPaint(
                              size: const Size(20, 20),
                              painter: _MiniSpinnerPainter(
                                t: spin.value,
                                color: tint,
                              ),
                            ),
                          )
                        : Container(
                            key: const ValueKey('wait'),
                            margin: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.textTertiary
                                  .resolveFrom(context)
                                  .withValues(alpha: 0.4),
                            ),
                          )),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 240),
              style: AppTextStyles.callout(
                context,
                emphasized: done,
                color: done ? AppColors.textPrimary : AppColors.textSecondary,
              ),
              child: Text(label),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cincin besar: lintasan redup, busur bergradasi yang berputar, dan denyut
/// cahaya di luarnya. Sesudah [done] menjadi lingkaran penuh berwarna hijau.
class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.t,
    required this.color,
    required this.doneColor,
    required this.done,
    required this.glow,
  });

  final double t;
  final Color color;
  final Color doneColor;
  final bool done;
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 8;
    if (glow && !done) {
      final pulse = 0.5 + 0.5 * math.sin(t * 2 * math.pi);
      canvas.drawCircle(
        c,
        r + 10 + pulse * 4,
        Paint()
          ..color = color.withValues(alpha: 0.10 + 0.10 * pulse)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
    }
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = (done ? doneColor : color).withValues(alpha: 0.16);
    canvas.drawCircle(c, r, track);
    final rect = Rect.fromCircle(center: c, radius: r);
    if (done) {
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..color = doneColor,
      );
      return;
    }
    final start = t * 2 * math.pi - math.pi / 2;
    const sweep = math.pi * 1.25;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(start);
    canvas.translate(-c.dx, -c.dy);
    canvas.drawArc(
      rect,
      0,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: sweep,
          colors: [color.withValues(alpha: 0), color],
          transform: const GradientRotation(0),
        ).createShader(rect),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.t != t || old.done != done || old.color != color;
}

class _MiniSpinnerPainter extends CustomPainter {
  const _MiniSpinnerPainter({required this.t, required this.color});

  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = rect.deflate(3);
    canvas.drawArc(
      r,
      t * 2 * math.pi,
      math.pi * 1.4,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_MiniSpinnerPainter old) => old.t != t;
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.name,
    required this.email,
    required this.colorHex,
    required this.circleLabel,
  });

  final String? name;
  final String? email;
  final String? colorHex;
  final String? circleLabel;

  @override
  Widget build(BuildContext context) {
    final success = AppColors.success.resolveFrom(context);
    final display = name ?? '';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh.resolveFrom(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.separator.resolveFrom(context)),
      ),
      child: Row(
        children: [
          MemberAvatar(
            name: display.isEmpty ? '?' : display,
            colorHex: colorHex ?? '#0F766E',
            size: 40,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      display,
                      style: AppTextStyles.callout(context, emphasized: true),
                    ),
                    if (display.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.tint
                              .resolveFrom(context)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          AuthStrings.confirmYou,
                          style: AppTextStyles.caption2(
                            context,
                            emphasized: true,
                            color: AppColors.tint,
                          ),
                        ),
                      ),
                  ],
                ),
                if (email != null)
                  Text(
                    email!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption1(
                      context,
                      color: AppColors.textSecondary,
                    ),
                  ),
                if (circleLabel != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Symbols.group, size: 14, color: success),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            circleLabel!,
                            style: AppTextStyles.caption1(
                              context,
                              emphasized: true,
                              color: AppColors.success,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
