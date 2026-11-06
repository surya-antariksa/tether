import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/theme/app_colors.dart';

/// Pilihan durasi masa aktif tautan berbagi rute live.
enum RouteShareDuration {
  oneHour('1 Jam'),
  sixHours('6 Jam'),
  twentyFourHours('24 Jam');

  const RouteShareDuration(this.label);
  final String label;
}

/// Target aplikasi eksternal untuk membagikan rute perjalanan.
enum ShareExternalApp {
  whatsApp('WhatsApp'),
  telegram('Telegram'),
  copyLink('Salin Tautan'),
  smsSos('SMS SOS');

  const ShareExternalApp(this.label);
  final String label;
}

/// Representasi anggota Circle pada lembar berbagi rute.
class ShareRouteMember {
  const ShareRouteMember({
    required this.id,
    required this.name,
    this.initial,
    this.batteryPct,
    this.colorHex,
  });

  final String id;
  final String name;
  final String? initial;
  final int? batteryPct;
  final String? colorHex;
}

/// Konstanta teks untuk lembar bagikan rute (Obsidian Dark Glass).
class ShareRouteStrings {
  static const title = 'Bagikan Rute Perjalanan';
  static const liveBadge = 'LIVE';
  static const subtitle = 'Tether Radar • Riwayat Terverifikasi';
  static const safe = 'Aman';
  static const circleSection = 'BAGIKAN KE CIRCLE';
  static const send = 'Kirim';
  static const sent = 'Terkirim';
  static const sendAll = 'Kirim Semua';
  static const oneTap = '1 Ketukan';
  static const externalSection = 'APLIKASI EKSTERNAL';
  static const whatsapp = 'WhatsApp';
  static const telegram = 'Telegram';
  static const copyLink = 'Salin Tautan';
  static const smsSos = 'SMS SOS';
  static const durationTitle = 'Tautan berlaku selama';
  static const autoExpire = 'Kedaluwarsa otomatis';
  static const duration1h = '1 Jam';
  static const duration6h = '6 Jam';
  static const duration24h = '24 Jam';
  static const encryptionBanner =
      '🔒 Tautan Terenkripsi PIN/Passkey • Hanya perangkat terotentikasi';
  static const copySummaryCta = 'Salin Tautan Ringkasan';
  static const copiedSuccess = 'Tautan Disalin! ✓';
  static const ctaFootnote =
      'Penerima dapat melihat progres live secara aman tanpa install aplikasi.';
  static const close = 'Tutup';
}

/// Menampilkan sheet modal Bagikan Rute Perjalanan Obsidian Dark Glass.
Future<void> showShareRouteSheet(
  BuildContext context, {
  String origin = 'Jl. Teuku Umar Barat',
  String destination = 'Jl. Raya Dalung No. 42',
  String distance = '3.8 km',
  String duration = '22 menit',
  String circleName = 'Lingkar Inti',
  List<ShareRouteMember> members = const [
    ShareRouteMember(
      id: '1',
      name: 'Gita',
      initial: 'G',
      batteryPct: 88,
      colorHex: '#00F2FE',
    ),
    ShareRouteMember(
      id: '2',
      name: 'Ibu',
      initial: 'I',
      batteryPct: 74,
      colorHex: '#4EDEA3',
    ),
    ShareRouteMember(
      id: '3',
      name: 'Ayah',
      initial: 'A',
      batteryPct: 95,
      colorHex: '#FFB347',
    ),
  ],
  ValueChanged<ShareRouteMember>? onSendMember,
  VoidCallback? onSendAll,
  ValueChanged<ShareExternalApp>? onExternalShare,
  VoidCallback? onCopyLink,
}) {
  return showCupertinoModalPopup<void>(
    context: context,
    builder: (_) => ShareRouteSheet(
      origin: origin,
      destination: destination,
      distance: distance,
      duration: duration,
      circleName: circleName,
      members: members,
      onSendMember: onSendMember,
      onSendAll: onSendAll,
      onExternalShare: onExternalShare,
      onCopyLink: onCopyLink,
    ),
  );
}

/// Lembar modal bawah (bottom sheet) Bagikan Rute Perjalanan bertema Obsidian Dark Glass.
class ShareRouteSheet extends StatefulWidget {
  const ShareRouteSheet({
    super.key,
    this.origin = 'Jl. Teuku Umar Barat',
    this.destination = 'Jl. Raya Dalung No. 42',
    this.distance = '3.8 km',
    this.duration = '22 menit',
    this.circleName = 'Lingkar Inti',
    this.members = const [
      ShareRouteMember(
        id: '1',
        name: 'Gita',
        initial: 'G',
        batteryPct: 88,
        colorHex: '#00F2FE',
      ),
      ShareRouteMember(
        id: '2',
        name: 'Ibu',
        initial: 'I',
        batteryPct: 74,
        colorHex: '#4EDEA3',
      ),
      ShareRouteMember(
        id: '3',
        name: 'Ayah',
        initial: 'A',
        batteryPct: 95,
        colorHex: '#FFB347',
      ),
    ],
    this.onSendMember,
    this.onSendAll,
    this.onExternalShare,
    this.onCopyLink,
  });

  final String origin;
  final String destination;
  final String distance;
  final String duration;
  final String circleName;
  final List<ShareRouteMember> members;
  final ValueChanged<ShareRouteMember>? onSendMember;
  final VoidCallback? onSendAll;
  final ValueChanged<ShareExternalApp>? onExternalShare;
  final VoidCallback? onCopyLink;

  @override
  State<ShareRouteSheet> createState() => _ShareRouteSheetState();
}

class _ShareRouteSheetState extends State<ShareRouteSheet> {
  final Set<String> _sentMemberIds = <String>{};
  RouteShareDuration _selectedDuration = RouteShareDuration.sixHours;
  bool _copied = false;

  void _sendToMember(ShareRouteMember member) {
    setState(() {
      if (_sentMemberIds.contains(member.id)) {
        _sentMemberIds.remove(member.id);
      } else {
        _sentMemberIds.add(member.id);
      }
    });
    widget.onSendMember?.call(member);
  }

  void _sendToAll() {
    setState(() {
      _sentMemberIds.addAll(widget.members.map((m) => m.id));
    });
    widget.onSendAll?.call();
  }

  Future<void> _handleCopy() async {
    final summaryText =
        '${widget.origin} ➔ ${widget.destination} (${widget.distance}, ${widget.duration}) - Tether Live Route';
    await Clipboard.setData(ClipboardData(text: summaryText));
    if (mounted) {
      setState(() => _copied = true);
    }
    widget.onCopyLink?.call();
  }

  void _handleExternalApp(ShareExternalApp app) {
    if (app == ShareExternalApp.copyLink) {
      _handleCopy();
    }
    widget.onExternalShare?.call(app);
  }

  @override
  Widget build(BuildContext context) {
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
                  color: AppColors.tint
                      .resolveFrom(context)
                      .withValues(alpha: 0.20),
                  width: 0.8,
                ),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x80000000),
                  blurRadius: 24,
                  offset: Offset(0, -6),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Drag Handle
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.textTertiary
                              .resolveFrom(context)
                              .withValues(alpha: 0.40),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),

                    // Sheet Header
                    _buildHeader(context),
                    const SizedBox(height: 16),

                    // Route Summary Pill Card
                    _buildRouteSummaryCard(),
                    const SizedBox(height: 18),

                    // Section 1: Bagikan ke Circle
                    _buildCircleSection(),
                    const SizedBox(height: 18),

                    // Section 2: Aplikasi Eksternal
                    _buildExternalAppsSection(),
                    const SizedBox(height: 18),

                    // Section 3: Link Duration & Encryption
                    _buildDurationAndSecuritySection(),
                    const SizedBox(height: 20),

                    // CTA Submit Button
                    _buildPrimaryCta(),
                    const SizedBox(height: 8),

                    // Footnote
                    Text(
                      ShareRouteStrings.ctaFootnote,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: AppColors.textTertiary.resolveFrom(context),
                        fontSize: 11,
                        height: 1.35,
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

  Widget _buildHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    ShareRouteStrings.title,
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      color: AppColors.textPrimary.resolveFrom(context),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.tint
                          .resolveFrom(context)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: AppColors.tint
                            .resolveFrom(context)
                            .withValues(alpha: 0.30),
                      ),
                    ),
                    child: Text(
                      ShareRouteStrings.liveBadge,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.tint.resolveFrom(context),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Symbols.verified_user,
                    size: 13,
                    color: AppColors.tint.resolveFrom(context),
                  ),
                  SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      ShareRouteStrings.subtitle,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: AppColors.textTertiary.resolveFrom(context),
                        fontSize: 12,
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
          onPressed: () => Navigator.of(context).pop(),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.separator
                  .resolveFrom(context)
                  .withValues(alpha: 0.15),
            ),
            child: Icon(
              Symbols.close,
              size: 16,
              color: AppColors.textPrimary.resolveFrom(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRouteSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.groupedItemBackground
            .resolveFrom(context)
            .withValues(alpha: 0.60),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.tint.resolveFrom(context).withValues(alpha: 0.20),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.tint
                      .resolveFrom(context)
                      .withValues(alpha: 0.15),
                ),
                child: Icon(
                  Symbols.near_me,
                  size: 14,
                  color: AppColors.tint.resolveFrom(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    Text(
                      widget.origin,
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        color: AppColors.textPrimary.resolveFrom(context),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '➔',
                      style: TextStyle(
                        color: AppColors.tint.resolveFrom(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      widget.destination,
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        color: AppColors.tint.resolveFrom(context),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 1,
            child: ColoredBox(
              color: AppColors.separator
                  .resolveFrom(context)
                  .withValues(alpha: 0.10),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh
                      .resolveFrom(context)
                      .withValues(alpha: 0.40),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Symbols.swap_horiz,
                      size: 13,
                      color: AppColors.textPrimary.resolveFrom(context),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.distance,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: AppColors.textPrimary.resolveFrom(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh
                      .resolveFrom(context)
                      .withValues(alpha: 0.40),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Symbols.schedule,
                      size: 13,
                      color: AppColors.success.resolveFrom(context),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.duration,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: AppColors.textPrimary.resolveFrom(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success
                      .resolveFrom(context)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.success
                        .resolveFrom(context)
                        .withValues(alpha: 0.30),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.success.resolveFrom(context),
                      ),
                      child: SizedBox(width: 6, height: 6),
                    ),
                    SizedBox(width: 5),
                    Text(
                      ShareRouteStrings.safe,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: AppColors.success.resolveFrom(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCircleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(
              ShareRouteStrings.circleSection,
              style: TextStyle(
                fontFamily: 'Inter',
                color: AppColors.textTertiary.resolveFrom(context),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            Text(
              widget.circleName,
              style: TextStyle(
                fontFamily: 'Inter',
                color: AppColors.tint.resolveFrom(context),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final member in widget.members) ...[
                _buildMemberCard(member),
                const SizedBox(width: 12),
              ],
              _buildSendAllCard(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMemberCard(ShareRouteMember member) {
    final isSent = _sentMemberIds.contains(member.id);
    final color = member.colorHex != null
        ? Color(int.parse(member.colorHex!.replaceFirst('#', '0xFF')))
        : AppColors.tint.resolveFrom(context);

    return Semantics(
      button: true,
      excludeSemantics: true,
      label:
          '${member.name}, ${isSent ? ShareRouteStrings.sent : ShareRouteStrings.send}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 1.5),
                ),
                padding: const EdgeInsets.all(2),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surfaceHigh.resolveFrom(context),
                  ),
                  child: Center(
                    child: Text(
                      member.initial ?? member.name[0].toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        color: AppColors.textPrimary.resolveFrom(context),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              if (member.batteryPct != null)
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.groupedBackground.resolveFrom(context),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppColors.separator
                            .resolveFrom(context)
                            .withValues(alpha: 0.20),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Symbols.battery_charging_full,
                          size: 9,
                          color: AppColors.success.resolveFrom(context),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${member.batteryPct}%',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 9,
                            color: AppColors.textSecondary.resolveFrom(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 64),
            child: Text(
              member.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                color: AppColors.textPrimary.resolveFrom(context),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 4),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(58, 26),
            onPressed: () => _sendToMember(member),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isSent
                    ? AppColors.success
                          .resolveFrom(context)
                          .withValues(alpha: 0.20)
                    : AppColors.tint
                          .resolveFrom(context)
                          .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isSent
                      ? AppColors.success
                            .resolveFrom(context)
                            .withValues(alpha: 0.40)
                      : AppColors.tint
                            .resolveFrom(context)
                            .withValues(alpha: 0.30),
                ),
              ),
              child: Text(
                isSent ? ShareRouteStrings.sent : ShareRouteStrings.send,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isSent
                      ? AppColors.success.resolveFrom(context)
                      : AppColors.tint.resolveFrom(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSendAllCard() {
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: '${ShareRouteStrings.sendAll}, ${ShareRouteStrings.oneTap}',
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: _sendToAll,
        child: Container(
          width: 82,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.tint.resolveFrom(context).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.tint
                  .resolveFrom(context)
                  .withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.tint
                      .resolveFrom(context)
                      .withValues(alpha: 0.20),
                ),
                child: Icon(
                  Symbols.send,
                  size: 18,
                  color: AppColors.tint.resolveFrom(context),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                ShareRouteStrings.sendAll,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.tint.resolveFrom(context),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                ShareRouteStrings.oneTap,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  color: AppColors.textTertiary.resolveFrom(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExternalAppsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ShareRouteStrings.externalSection,
          style: TextStyle(
            fontFamily: 'Inter',
            color: AppColors.textTertiary.resolveFrom(context),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildExternalAppTile(
              app: ShareExternalApp.whatsApp,
              icon: Symbols.chat_bubble,
              iconBgColor: AppColors.success
                  .resolveFrom(context)
                  .withValues(alpha: 0.20),
              iconColor: AppColors.success.resolveFrom(context),
            ),
            const SizedBox(width: 8),
            _buildExternalAppTile(
              app: ShareExternalApp.telegram,
              icon: Symbols.send,
              iconBgColor: AppColors.tint
                  .resolveFrom(context)
                  .withValues(alpha: 0.15),
              iconColor: AppColors.tint.resolveFrom(context),
            ),
            const SizedBox(width: 8),
            _buildExternalAppTile(
              app: ShareExternalApp.copyLink,
              icon: Symbols.link,
              iconBgColor: AppColors.separator
                  .resolveFrom(context)
                  .withValues(alpha: 0.15),
              iconColor: AppColors.textPrimary.resolveFrom(context),
            ),
            const SizedBox(width: 8),
            _buildExternalAppTile(
              app: ShareExternalApp.smsSos,
              icon: Symbols.gpp_maybe,
              iconBgColor: AppColors.danger
                  .resolveFrom(context)
                  .withValues(alpha: 0.20),
              iconColor: AppColors.danger.resolveFrom(context),
              isEmergency: true,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildExternalAppTile({
    required ShareExternalApp app,
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    bool isEmergency = false,
  }) {
    return Expanded(
      child: Semantics(
        button: true,
        excludeSemantics: true,
        label: app.label,
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _handleExternalApp(app),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            decoration: BoxDecoration(
              color: isEmergency
                  ? AppColors.danger
                        .resolveFrom(context)
                        .withValues(alpha: 0.12)
                  : AppColors.groupedItemBackground
                        .resolveFrom(context)
                        .withValues(alpha: 0.40),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isEmergency
                    ? AppColors.danger
                          .resolveFrom(context)
                          .withValues(alpha: 0.30)
                    : AppColors.separator
                          .resolveFrom(context)
                          .withValues(alpha: 0.10),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: iconBgColor,
                  ),
                  child: Icon(icon, size: 20, color: iconColor),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    app.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: isEmergency
                          ? AppColors.danger.resolveFrom(context)
                          : AppColors.textPrimary.resolveFrom(context),
                      fontSize: 11,
                      fontWeight: isEmergency
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDurationAndSecuritySection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.groupedItemBackground
            .resolveFrom(context)
            .withValues(alpha: 0.40),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.separator
              .resolveFrom(context)
              .withValues(alpha: 0.10),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Symbols.schedule,
                    size: 15,
                    color: AppColors.tint.resolveFrom(context),
                  ),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      ShareRouteStrings.durationTitle,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: AppColors.textPrimary.resolveFrom(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                ShareRouteStrings.autoExpire,
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: AppColors.textTertiary.resolveFrom(context),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.groupedBackground.resolveFrom(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.separator
                    .resolveFrom(context)
                    .withValues(alpha: 0.10),
              ),
            ),
            child: Row(
              children: [
                for (final d in RouteShareDuration.values)
                  Expanded(
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      minimumSize: const Size(0, 36),
                      onPressed: () => setState(() => _selectedDuration = d),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: _selectedDuration == d
                              ? AppColors.surfaceHigh.resolveFrom(context)
                              : CupertinoColors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: _selectedDuration == d
                              ? Border.all(
                                  color: AppColors.tint
                                      .resolveFrom(context)
                                      .withValues(alpha: 0.30),
                                )
                              : null,
                        ),
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              d.label,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: _selectedDuration == d
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: _selectedDuration == d
                                    ? AppColors.tint.resolveFrom(context)
                                    : AppColors.textTertiary.resolveFrom(
                                        context,
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh
                  .resolveFrom(context)
                  .withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.separator
                    .resolveFrom(context)
                    .withValues(alpha: 0.10),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Symbols.lock,
                  size: 14,
                  color: AppColors.success.resolveFrom(context),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ShareRouteStrings.encryptionBanner,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: AppColors.textSecondary.resolveFrom(context),
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryCta() {
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: _copied
          ? ShareRouteStrings.copiedSuccess
          : ShareRouteStrings.copySummaryCta,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.tint.resolveFrom(context),
              AppColors.tint.resolveFrom(context),
            ],
          ),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: AppColors.tint
                  .resolveFrom(context)
                  .withValues(alpha: 0.40),
              blurRadius: 14,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          minimumSize: const Size.fromHeight(48),
          onPressed: _handleCopy,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _copied ? Symbols.check : Symbols.content_copy,
                size: 18,
                color: AppColors.groupedBackground.resolveFrom(context),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  _copied
                      ? ShareRouteStrings.copiedSuccess
                      : ShareRouteStrings.copySummaryCta,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    color: AppColors.groupedBackground.resolveFrom(context),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
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
