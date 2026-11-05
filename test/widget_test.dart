import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tether/features/location_tracking/presentation/spike_page.dart';

void main() {
  testWidgets('SpikePage tampil tanpa Supabase dan tidak crash saat mulai', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const CupertinoApp(home: SpikePage(supabaseConfigured: false)),
    );

    expect(find.text('Mulai rute simulasi'), findsOneWidget);
    expect(find.text('Berhenti'), findsAtLeastNWidgets(1));
    expect(find.text('Putuskan jaringan (simulasi)'), findsOneWidget);
    expect(find.text('Antrean'), findsOneWidget);
    expect(find.text('Terkirim'), findsOneWidget);

    await tester.tap(find.text('Mulai rute simulasi'));
    await tester.pump();

    expect(find.textContaining('SUPABASE_URL kosong'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
