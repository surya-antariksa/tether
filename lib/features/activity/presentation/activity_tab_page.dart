import 'package:flutter/cupertino.dart';

/// Placeholder Sprint 1. Diganti saat fitur activity dikerjakan.
class ActivityTabPage extends StatelessWidget {
  const ActivityTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(middle: Text('Aktivitas')),
      child: Center(child: Text('Aktivitas segera hadir.')),
    );
  }
}
