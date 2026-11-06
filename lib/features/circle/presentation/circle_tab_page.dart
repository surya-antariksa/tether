import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/selected_circle.dart';
import '../../../core/widgets/design_widgets.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/member_avatar.dart';
import '../../../core/widgets/primary_button.dart';
import '../../auth/data/auth_providers.dart';
import '../circle_routes.dart';
import '../data/circle_providers.dart';
import '../domain/circle.dart';
import 'circle_dialogs.dart';
import 'circle_strings.dart';
import 'invite_sheet.dart';

class CircleTabPage extends ConsumerWidget {
  const CircleTabPage({super.key});

  Future<void> _refresh(BuildContext context, WidgetRef ref) async {
    ref.invalidate(myCirclesProvider);
    try {
      final circles = await ref.read(myCirclesProvider.future);
      final id = ref.read(selectedCircleIdProvider);
      if (id != null && circles.any((c) => c.id == id)) {
        await ref.read(membersProvider(id).notifier).refresh();
      }
    } catch (e) {
      if (context.mounted) await showCircleError(context, e);
    }
  }

  Future<void> _showAddSheet(BuildContext context) {
    return showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.push(CircleRoutes.create);
            },
            child: const Text(CircleStrings.createNew),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.push(CircleRoutes.join);
            },
            child: const Text(CircleStrings.joinWithCode),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text(CircleStrings.cancel),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final circles = ref.watch(myCirclesProvider);
    final hasCircles = circles.value?.isNotEmpty ?? false;
    return CupertinoPageScaffold(
      backgroundColor: AppColors.groupedBackground,
      child: AtmosphereBackground(
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: [
              CupertinoSliverRefreshControl(
                onRefresh: () => _refresh(context, ref),
              ),
              SliverToBoxAdapter(
                child: _TitleBar(
                  onAdd: hasCircles ? () => _showAddSheet(context) : null,
                ),
              ),
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: circles.when(
                      skipLoadingOnReload: true,
                      data: (list) => list.isEmpty
                          ? const _EmptyState()
                          : _CircleContent(circles: list),
                      loading: () => const Padding(
                        padding: EdgeInsets.all(48),
                        child: Center(child: CupertinoActivityIndicator()),
                      ),
                      error: (_, _) => _LoadFailed(
                        message: CircleStrings.loadFailed,
                        onRetry: () => ref.invalidate(myCirclesProvider),
                      ),
                    ),
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

/// Judul halaman: "Circle", subjudul, lencana Aktif, dan tombol tambah.
class _TitleBar extends StatelessWidget {
  const _TitleBar({required this.onAdd});

  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    CircleStrings.title,
                    style: AppTextStyles.largeTitle(context, emphasized: true),
                  ),
                ),
                Text(
                  CircleStrings.subtitle,
                  style: AppTextStyles.footnote(
                    context,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (onAdd != null) ...[
            Semantics(
              button: true,
              label: CircleStrings.add,
              excludeSemantics: true,
              onTap: onAdd,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(44, 44),
                onPressed: onAdd,
                child: Icon(
                  Symbols.add,
                  color: AppColors.tint.resolveFrom(context),
                ),
              ),
            ),
          ],
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: StatusBadge(
              text: CircleStrings.activeBadge,
              dotColor: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends ConsumerWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Tidak ada Circle: kosongkan pilihan lama (setelah build selesai).
    if (ref.read(selectedCircleIdProvider) != null) {
      Future.microtask(() {
        if (context.mounted) {
          ref.read(selectedCircleIdProvider.notifier).select(null);
        }
      });
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 64, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Symbols.group,
            size: 64,
            color: CupertinoDynamicColor.resolve(
              AppColors.textSecondary,
              context,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            CircleStrings.emptyTitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.title2(context, emphasized: true),
          ),
          const SizedBox(height: 8),
          Text(
            CircleStrings.emptyBody,
            textAlign: TextAlign.center,
            style: AppTextStyles.body(context, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 32),
          PrimaryButton(
            label: CircleStrings.create,
            busyLabel: CircleStrings.processing,
            onPressed: () => context.push(CircleRoutes.create),
          ),
          const SizedBox(height: 8),
          CupertinoButton(
            minimumSize: const Size.fromHeight(44),
            onPressed: () => context.push(CircleRoutes.join),
            child: Text(
              CircleStrings.joinWithCode,
              style: AppTextStyles.body(context, color: AppColors.tint),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.body(context),
          ),
          const SizedBox(height: 12),
          CupertinoButton(
            minimumSize: const Size(44, 44),
            onPressed: onRetry,
            child: const Text(CircleStrings.retry),
          ),
        ],
      ),
    );
  }
}

class _CircleContent extends ConsumerStatefulWidget {
  const _CircleContent({required this.circles});

  final List<Circle> circles;

  @override
  ConsumerState<_CircleContent> createState() => _CircleContentState();
}

class _CircleContentState extends ConsumerState<_CircleContent> {
  bool _inviting = false;
  bool _sharing = false;

  Future<void> _switch(Circle current) async {
    final picked = await showCupertinoModalPopup<Circle>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text(CircleStrings.switchLabel),
        actions: [
          for (final c in widget.circles)
            CupertinoActionSheetAction(
              isDefaultAction: c.id == current.id,
              onPressed: () => Navigator.of(ctx).pop(c),
              child: Text(c.name),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text(CircleStrings.cancel),
        ),
      ),
    );
    if (picked != null) {
      ref.read(selectedCircleIdProvider.notifier).select(picked.id);
    }
  }

  Future<void> _invite(Circle current) async {
    if (_inviting) return;
    setState(() => _inviting = true);
    CircleInvite invite;
    try {
      invite = await ref
          .read(circleRepositoryProvider)
          .createInvite(current.id);
    } catch (e) {
      if (mounted) {
        setState(() => _inviting = false);
        await showCircleError(context, e);
      }
      return;
    }
    if (!mounted) return;
    setState(() => _inviting = false);
    await showInviteSheet(context, invite);
  }

  Future<void> _leave(Circle current, int memberCount) async {
    final ok = await confirmDestructive(
      context,
      title: CircleStrings.leaveTitle(current.name),
      message: memberCount <= 1
          ? CircleStrings.leaveLastMessage
          : CircleStrings.leaveMessage,
      action: CircleStrings.leaveAction,
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(circleRepositoryProvider).leaveCircle(current.id);
      ref.invalidate(myCirclesProvider);
      await ref.read(myCirclesProvider.future);
    } catch (e) {
      if (mounted) await showCircleError(context, e);
    }
  }

  Future<void> _remove(Circle current, CircleMember member) async {
    final ok = await confirmDestructive(
      context,
      title: CircleStrings.removeTitle(member.displayName),
      message: CircleStrings.removeMessage,
      action: CircleStrings.remove,
    );
    if (!ok || !mounted) return;
    try {
      await ref
          .read(circleRepositoryProvider)
          .removeMember(current.id, member.userId);
      await ref.read(membersProvider(current.id).notifier).refresh();
    } catch (e) {
      if (mounted) await showCircleError(context, e);
    }
  }

  /// Sakelar berbagi jangka panjang (set_sharing_enabled). Nilai sakelar tetap
  /// mengikuti server: kalau gagal, anggota dimuat ulang dan sakelar kembali.
  Future<void> _toggleSharing(Circle current, bool enabled) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    bool ok = true;
    try {
      await ref
          .read(circleRepositoryProvider)
          .setSharingEnabled(current.id, enabled);
    } catch (e) {
      ok = false;
      if (mounted) await showCircleError(context, e);
    }
    if (ok && mounted) {
      await ref.read(membersProvider(current.id).notifier).refresh();
    }
    if (mounted) setState(() => _sharing = false);
  }

  @override
  Widget build(BuildContext context) {
    final circles = widget.circles;
    final selectedId = ref.watch(selectedCircleIdProvider);
    final current = circles.firstWhere(
      (c) => c.id == selectedId,
      orElse: () => circles.first,
    );
    if (selectedId != current.id) {
      // Pilih Circle pertama bila belum ada pilihan (atau pilihan sudah hilang).
      Future.microtask(() {
        if (mounted) {
          ref.read(selectedCircleIdProvider.notifier).select(current.id);
        }
      });
    }
    final members = ref.watch(membersProvider(current.id));
    final uid = ref.watch(currentUserIdProvider);
    final list = members.value ?? const <CircleMember>[];
    final isAdmin = list.any((m) => m.userId == uid && m.isAdmin);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CircleHeader(
            circle: current,
            memberCount: members.hasValue ? list.length : null,
            onSwitch: circles.length > 1 ? () => _switch(current) : null,
            invite: isAdmin
                ? TintPillButton(
                    label: _inviting
                        ? CircleStrings.inviting
                        : CircleStrings.invite,
                    icon: Symbols.person_add,
                    expand: true,
                    busy: _inviting,
                    onPressed: () => _invite(current),
                  )
                : null,
          ),
          if (members.hasValue && list.any((m) => m.userId == uid)) ...[
            const SizedBox(height: 16),
            const _SectionHeader(CircleStrings.sharingSection),
            _ShareCard(
              enabled: list.firstWhere((m) => m.userId == uid).sharingEnabled,
              busy: _sharing,
              onChanged: (v) => _toggleSharing(current, v),
            ),
          ],
          const SizedBox(height: 24),
          const _SectionHeader(CircleStrings.membersSection),
          members.when(
            skipLoadingOnReload: true,
            data: (_) => _MembersCard(
              members: list,
              currentUserId: uid,
              canRemove: isAdmin,
              onRemove: (m) => _remove(current, m),
            ),
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CupertinoActivityIndicator()),
            ),
            error: (_, _) => _LoadFailed(
              message: CircleStrings.membersLoadFailed,
              onRetry: () => ref.invalidate(membersProvider(current.id)),
            ),
          ),
          const SizedBox(height: 32),
          _DangerButton(
            label: CircleStrings.leave,
            icon: Symbols.logout,
            onPressed: members.hasValue
                ? () => _leave(current, list.length)
                : null,
          ),
          // Ruang untuk tab bar melayang.
          const SizedBox(height: 72),
        ],
      ),
    );
  }
}

class _CircleHeader extends StatelessWidget {
  const _CircleHeader({
    required this.circle,
    required this.memberCount,
    required this.onSwitch,
    required this.invite,
  });

  final Circle circle;
  final int? memberCount;
  final VoidCallback? onSwitch;

  /// Tombol undang (hanya admin).
  final Widget? invite;

  @override
  Widget build(BuildContext context) {
    final tint = AppColors.tint.resolveFrom(context);
    final info = Row(
      children: [
        ExcludeSemantics(child: Icon(Symbols.shield, size: 28, color: tint)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                circle.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.title2(context, emphasized: true),
              ),
              if (memberCount != null)
                Text(
                  CircleStrings.memberCount(memberCount!),
                  style: AppTextStyles.callout(
                    context,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
        if (onSwitch != null)
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh.resolveFrom(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.separator.resolveFrom(context),
              ),
            ),
            child: Icon(
              Symbols.swap_horiz,
              size: 22,
              color: AppColors.textSecondary.resolveFrom(context),
            ),
          ),
      ],
    );
    final tappable = onSwitch == null
        ? info
        : Semantics(
            button: true,
            label: '${CircleStrings.switchCircle}: ${circle.name}',
            excludeSemantics: true,
            onTap: onSwitch,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onSwitch,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: info,
              ),
            ),
          );
    return GlassCard(
      padding: const EdgeInsets.all(20),
      glow: tint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          tappable,
          if (invite != null) ...[const SizedBox(height: 16), invite!],
        ],
      ),
    );
  }
}

class _MembersCard extends StatelessWidget {
  const _MembersCard({
    required this.members,
    required this.currentUserId,
    required this.canRemove,
    required this.onRemove,
  });

  final List<CircleMember> members;
  final String? currentUserId;
  final bool canRemove;
  final void Function(CircleMember) onRemove;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return _Card(
      child: Column(
        children: [
          for (var i = 0; i < members.length; i++) ...[
            if (i > 0)
              Container(
                height: 0.5,
                margin: const EdgeInsetsDirectional.only(start: 76),
                color: CupertinoDynamicColor.resolve(
                  AppColors.separator,
                  context,
                ),
              ),
            _MemberRow(
              member: members[i],
              isSelf: members[i].userId == currentUserId,
              status: members[i].statusAt(now),
              canRemove: canRemove && members[i].userId != currentUserId,
              onRemove: () => onRemove(members[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.isSelf,
    required this.status,
    required this.canRemove,
    required this.onRemove,
  });

  final CircleMember member;
  final bool isSelf;
  final SharingStatus status;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final secondary = CupertinoDynamicColor.resolve(
      AppColors.textSecondary,
      context,
    );
    final statusIcon = switch (status) {
      SharingStatus.sharing => Symbols.near_me,
      SharingStatus.paused => Symbols.pause_circle,
      SharingStatus.off => Symbols.location_off,
    };
    // Teks besar: tombol Keluarkan pindah ke bawah teks agar nama tidak terjepit.
    final stacked = MediaQuery.textScalerOf(context).scale(17) > 17 * 1.3;
    final removeButton = Semantics(
      button: true,
      label: CircleStrings.removeLabel(member.displayName),
      excludeSemantics: true,
      onTap: onRemove,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onRemove,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.danger
                    .resolveFrom(context)
                    .withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.danger
                      .resolveFrom(context)
                      .withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                CircleStrings.remove,
                style: AppTextStyles.labelMd(context, color: AppColors.danger),
              ),
            ),
          ),
        ),
      ),
    );
    final statusColor = status == SharingStatus.sharing
        ? AppColors.success.resolveFrom(context)
        : secondary;
    final info = Semantics(
      container: true,
      label: CircleStrings.memberLabel(member.displayName, member.role, status),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                member.displayName,
                style: AppTextStyles.body(context, emphasized: true),
              ),
              if (isSelf)
                Text(
                  CircleStrings.you,
                  style: AppTextStyles.footnote(
                    context,
                    color: AppColors.textSecondary,
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh.resolveFrom(context),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  CircleStrings.role(member.role),
                  style: AppTextStyles.caption2(
                    context,
                    emphasized: true,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2, right: 4),
                child: Icon(statusIcon, size: 14, color: statusColor),
              ),
              Expanded(
                child: Text(
                  CircleStrings.status(status),
                  style: AppTextStyles.footnote(context, color: statusColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    final avatar = Stack(
      clipBehavior: Clip.none,
      children: [
        MemberAvatar(
          name: member.displayName,
          colorHex: member.color,
          size: 48,
        ),
        Positioned(
          right: -1,
          bottom: -1,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: statusColor,
              border: Border.all(
                color: AppColors.groupedItemBackground.resolveFrom(context),
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                avatar,
                const SizedBox(width: 12),
                Expanded(child: info),
                if (canRemove && !stacked) removeButton,
              ],
            ),
            if (canRemove && stacked)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 60),
                child: removeButton,
              ),
          ],
        ),
      ),
    );
  }
}

/// Kartu sakelar berbagi jangka panjang (per Circle) milik sendiri.
class _ShareCard extends StatelessWidget {
  const _ShareCard({
    required this.enabled,
    required this.busy,
    required this.onChanged,
  });

  final bool enabled;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ExcludeSemantics(
                        child: Icon(
                          Symbols.location_on,
                          size: 22,
                          color: AppColors.success.resolveFrom(context),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          CircleStrings.sharingRow,
                          style: AppTextStyles.body(context, emphasized: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    CircleStrings.sharingHint,
                    style: AppTextStyles.footnote(
                      context,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            CupertinoSwitch(
              value: enabled,
              activeTrackColor: AppColors.success.resolveFrom(context),
              onChanged: busy ? null : onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

/// Tombol destruktif bergaya hantu: latar merah 8%, garis merah 25%.
class _DangerButton extends StatelessWidget {
  const _DangerButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.danger.resolveFrom(context);
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: Opacity(
        opacity: onPressed == null ? 0.5 : 1,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.withValues(alpha: 0.28)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 22, color: c),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body(
                      context,
                      emphasized: true,
                      color: AppColors.danger,
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
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlassCard(padding: EdgeInsets.zero, child: child);
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SectionLabel(text),
    );
  }
}
