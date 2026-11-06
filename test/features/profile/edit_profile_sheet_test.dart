import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tether/features/profile/domain/profile.dart';
import 'package:tether/features/profile/presentation/edit_profile_sheet.dart';

void main() {
  testWidgets('menampilkan header, input nama, dan bento HUD avatar', (
    tester,
  ) async {
    const profile = Profile(
      id: 'user-1',
      displayName: 'suryantariksa',
      color: '#00F2FE',
    );

    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: Builder(
            builder: (context) => CupertinoButton(
              onPressed: () => showEditProfileSheet(
                context,
                profile: profile,
                onSave: ({displayName, color}) async {},
              ),
              child: const Text('Buka'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Buka'));
    await tester.pumpAndSettle();

    expect(find.text('Ubah Profil Publik Circle'), findsOneWidget);
    expect(find.text('Nama Tampilan'), findsOneWidget);
    expect(find.text('13/24'), findsOneWidget);
    expect(find.text('S'), findsOneWidget); // Initial
    expect(find.text('Pratinjau tampilan Anda di peta'), findsOneWidget);
    expect(find.text('Pilih Warna Penanda di Peta'), findsOneWidget);
    expect(find.text('Teal Cyan'), findsOneWidget);
    expect(find.text('Simpan Perubahan'), findsOneWidget);
  });

  testWidgets('memilih warna memperbarui label dan menyimpan warna baru', (
    tester,
  ) async {
    const profile = Profile(
      id: 'user-1',
      displayName: 'suryantariksa',
      color: '#00F2FE',
    );

    String? savedName;
    String? savedColor;

    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: Builder(
            builder: (context) => CupertinoButton(
              onPressed: () => showEditProfileSheet(
                context,
                profile: profile,
                onSave: ({displayName, color}) async {
                  savedName = displayName;
                  savedColor = color;
                },
              ),
              child: const Text('Buka'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Buka'));
    await tester.pumpAndSettle();

    // Tap color Neon Green
    await tester.tap(find.bySemanticsLabel('Warna Neon Green'));
    await tester.pumpAndSettle();

    expect(find.text('Neon Green'), findsOneWidget);

    // Scroll to and tap Simpan
    await tester.ensureVisible(find.text('Simpan Perubahan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan Perubahan'));
    await tester.pumpAndSettle();

    expect(savedColor, '#4EDEA3');
    expect(savedName, isNull);
  });
}
