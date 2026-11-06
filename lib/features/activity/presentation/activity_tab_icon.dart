import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../data/activity_providers.dart';
import 'activity_strings.dart';

/// Warna lencana (putih di atasnya berkontras sekitar 6,5:1).
const activityBadgeColor = Color(0xFFB91C1C);

/// Ikon tab Aktivitas dengan lencana jumlah belum dibaca. Menonton
/// [activityUnreadProvider], sehingga memasangnya di tab bar juga menjaga
/// pemantau event dan notifikasi lokal tetap hidup selama aplikasi terbuka.
class ActivityTabIcon extends ConsumerWidget {
  const ActivityTabIcon({super.key, this.filled = false});

  /// Ikon terisi untuk tab aktif.
  final bool filled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(activityUnreadProvider);
    return Semantics(
      label: unread > 0 ? ActivityStrings.unreadLabel(unread) : null,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(Symbols.notifications, fill: filled ? 1 : 0),
          if (unread > 0)
            Positioned(
              top: -4,
              right: -10,
              child: ExcludeSemantics(child: _Badge(count: unread)),
            ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: activityBadgeColor,
        borderRadius: BorderRadius.circular(9),
      ),
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: Text(
          count >= 100 ? ActivityStrings.tabBadgeMax : '$count',
          style: const TextStyle(
            color: CupertinoColors.white,
            fontSize: 11,
            height: 1.2,
            fontWeight: FontWeight.w700,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}
