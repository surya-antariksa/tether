import 'package:flutter/cupertino.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/primary_button.dart';
import '../domain/circle.dart';
import '../domain/invite_code.dart';
import 'circle_strings.dart';

/// Menampilkan kode undangan dalam sheet modal Obsidian dengan kode monospace,
/// cyber QR code, dan aksi bagikan.
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
    final isDark = AppColors.isDark(context);

    return DefaultTextStyle(
      style: CupertinoTheme.of(context).textTheme.textStyle,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: CupertinoDynamicColor.resolve(
                AppColors.groupedBackground,
                context,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              border: Border(
                top: BorderSide(
                  color: CupertinoDynamicColor.resolve(
                    AppColors.separator,
                    context,
                  ),
                  width: 0.5,
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top drag notch
                    Center(
                      child: Container(
                        width: 48,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: CupertinoDynamicColor.resolve(
                            CupertinoColors.systemGrey3,
                            context,
                          ).withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),

                    // Sheet Header Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Semantics(
                                header: true,
                                child: Text(
                                  CircleStrings.inviteTitle,
                                  style: AppTextStyles.title3(
                                    context,
                                    emphasized: true,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.success.resolveFrom(
                                        context,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Kode Aktif • Sinkron Realtime',
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.footnote(
                                        context,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(32, 32),
                          borderRadius: BorderRadius.circular(99),
                          color: CupertinoDynamicColor.resolve(
                            AppColors.groupedItemBackground,
                            context,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          child: Icon(
                            Symbols.close,
                            size: 16,
                            color: AppColors.textSecondary.resolveFrom(context),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Big Invite Code Display Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: CupertinoDynamicColor.resolve(
                          AppColors.groupedItemBackground,
                          context,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: AppColors.tint
                              .resolveFrom(context)
                              .withValues(alpha: 0.3),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.tint
                                .resolveFrom(context)
                                .withValues(alpha: 0.10),
                            blurRadius: 18,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'KODE UNDANGAN EKSKLUSIF',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.8,
                                        color: AppColors.tint.resolveFrom(
                                          context,
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Bagikan kode ini untuk bergabung langsung',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary
                                            .resolveFrom(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.tint
                                      .resolveFrom(context)
                                      .withValues(alpha: 0.13),
                                  borderRadius: BorderRadius.circular(99),
                                  border: Border.all(
                                    color: AppColors.tint
                                        .resolveFrom(context)
                                        .withValues(alpha: 0.27),
                                    width: 0.6,
                                  ),
                                ),
                                child: Text(
                                  'Private',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.tint.resolveFrom(context),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Monospace Code Container
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.groupedBackground.resolveFrom(
                                      context,
                                    )
                                  : CupertinoColors.systemGrey6,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: CupertinoDynamicColor.resolve(
                                  AppColors.separator,
                                  context,
                                ),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Semantics(
                                    label: CircleStrings.inviteCodeLabel(code),
                                    excludeSemantics: true,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        code,
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 26,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 6,
                                          color: isDark
                                              ? AppColors.tint.resolveFrom(
                                                  context,
                                                )
                                              : AppColors.tint.resolveFrom(
                                                  context,
                                                ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: CupertinoButton(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    minimumSize: Size.zero,
                                    color: CupertinoDynamicColor.resolve(
                                      AppColors.groupedItemBackground,
                                      context,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    onPressed: _copy,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _copied
                                              ? Symbols.check_circle
                                              : Symbols.content_copy,
                                          size: 14,
                                          color: _copied
                                              ? AppColors.success.resolveFrom(
                                                  context,
                                                )
                                              : AppColors.tint.resolveFrom(
                                                  context,
                                                ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _copied ? 'Tersalin' : 'Salin',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: _copied
                                                ? AppColors.success.resolveFrom(
                                                    context,
                                                  )
                                                : AppColors.textPrimary
                                                      .resolveFrom(context),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 10),

                          // Expiration & note
                          Text(
                            CircleStrings.inviteExpires(
                              CircleStrings.formatWhen(widget.invite.expiresAt),
                            ),
                            style: AppTextStyles.footnote(
                              context,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            CircleStrings.inviteNote,
                            style: AppTextStyles.caption2(
                              context,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Futuristic QR Code Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: CupertinoDynamicColor.resolve(
                          AppColors.groupedItemBackground,
                          context,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: CupertinoDynamicColor.resolve(
                            AppColors.separator,
                            context,
                          ).withValues(alpha: 0.4),
                          width: 0.6,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Pindai Kode QR',
                            style: AppTextStyles.headline(context),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Atau pindai QR langsung dari aplikasi Tether',
                            style: AppTextStyles.footnote(
                              context,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 14),

                          // QR sungguhan: isinya tautan undangan. Selalu gelap di
                          // atas putih agar terbaca pemindai di semua tema.
                          Center(
                            child: Semantics(
                              image: true,
                              label: 'QR undangan, kode $code',
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFFFFF),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: QrImageView(
                                  key: const ValueKey('invite-qr'),
                                  data: InviteCode.link(code),
                                  size: 148,
                                  padding: EdgeInsets.zero,
                                  backgroundColor: const Color(0xFFFFFFFF),
                                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                                  eyeStyle: const QrEyeStyle(
                                    eyeShape: QrEyeShape.square,
                                    color: Color(0xFF0B3B4A),
                                  ),
                                  dataModuleStyle: const QrDataModuleStyle(
                                    dataModuleShape: QrDataModuleShape.square,
                                    color: Color(0xFF0B3B4A),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),

                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Symbols.crop_free,
                                  size: 14,
                                  color: AppColors.tint.resolveFrom(context),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Arahkan kamera anggota baru',
                                  style: TextStyle(
                                    fontSize: 11,
                                    letterSpacing: 0.4,
                                    color: AppColors.tint.resolveFrom(context),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Primary Button: Bagikan
                    PrimaryButton(
                      label: _copied
                          ? CircleStrings.copied
                          : CircleStrings.copy,
                      busyLabel: CircleStrings.copy,
                      onPressed: _copy,
                    ),

                    const SizedBox(height: 8),

                    // Done Button
                    CupertinoButton(
                      minimumSize: const Size.fromHeight(44),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(CircleStrings.done),
                    ),

                    // Security Guarantee Banner
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: CupertinoDynamicColor.resolve(
                          AppColors.groupedItemBackground,
                          context,
                        ).withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Symbols.lock,
                            size: 14,
                            color: AppColors.success.resolveFrom(context),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Hanya yang memiliki kode ini yang dapat melihat Circle. Enkripsi E2E aktif.',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary.resolveFrom(
                                  context,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
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
