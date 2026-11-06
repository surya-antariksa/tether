import 'package:flutter/cupertino.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../domain/invite_code.dart';
import 'circle_strings.dart';

/// Pemindai QR undangan layar penuh. Mengembalikan kode 6 karakter lewat
/// `Navigator.pop`, atau null bila dibatalkan. QR yang bukan undangan Tether
/// diabaikan dengan petunjuk, kamera tetap jalan.
class ScanInvitePage extends StatefulWidget {
  const ScanInvitePage({super.key});

  @override
  State<ScanInvitePage> createState() => _ScanInvitePageState();
}

class _ScanInvitePageState extends State<ScanInvitePage> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _done = false;
  bool _invalid = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final b in capture.barcodes) {
      final code = InviteCode.fromScan(b.rawValue);
      if (code != null) {
        _done = true;
        Navigator.of(context).pop(code);
        return;
      }
    }
    if (!_invalid) setState(() => _invalid = true);
  }

  @override
  Widget build(BuildContext context) {
    final tint = AppColors.tint.resolveFrom(context);
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFF000000),
      navigationBar: CupertinoNavigationBar(
        middle: const Text(CircleStrings.scanTitle),
        backgroundColor: const Color(0xCC000000),
        automaticBackgroundVisibility: false,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  CircleStrings.scanError,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body(
                    context,
                    color: const Color(0xFFFFFFFF),
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: tint, width: 3),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 48,
            child: SafeArea(
              top: false,
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _invalid ? CircleStrings.scanInvalid : CircleStrings.scanHint,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.callout(
                    context,
                    color: const Color(0xFFFFFFFF),
                  ),
                ),
              ),
            ),
          ),
          const Positioned(
            right: 16,
            top: 100,
            child: Icon(Symbols.qr_code_scanner, color: Color(0xFFFFFFFF)),
          ),
        ],
      ),
    );
  }
}
