import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/circle_providers.dart';
import '../domain/circle.dart';
import '../domain/circle_error.dart';
import '../domain/invite_code.dart';
import 'circle_strings.dart';
import 'scan_invite_page.dart';

/// Huruf besar, spasi dan karakter di luar alfabet kode dibuang, maksimal 6.
class InviteCodeFormatter extends TextInputFormatter {
  const InviteCodeFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = InviteCode.normalize(newValue.text);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Alur gabung: kode -> pratinjau -> konfirmasi -> join.
class JoinCirclePage extends ConsumerStatefulWidget {
  const JoinCirclePage({super.key, this.initialCode});

  /// Kode dari deep link atau QR; mengisi kolom di awal.
  final String? initialCode;

  @override
  ConsumerState<JoinCirclePage> createState() => _JoinCirclePageState();
}

class _JoinCirclePageState extends ConsumerState<JoinCirclePage> {
  late final _controller = TextEditingController(
    text: InviteCode.normalize(widget.initialCode ?? ''),
  );
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Kamera hanya ada di Android dan iOS.
  bool get _canScan =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> _scan() async {
    final code = await Navigator.of(
      context,
    ).push<String>(CupertinoPageRoute(builder: (_) => const ScanInvitePage()));
    if (code == null || !mounted) return;
    setState(() {
      _controller.text = code;
      _error = null;
    });
    await _next();
  }

  Future<bool> _confirm(InvitePreview preview) async {
    final ok = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(
          CircleStrings.joinConfirm(preview.circleName, preview.memberCount),
        ),
        actions: [
          CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(CircleStrings.joinAction),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text(CircleStrings.cancel),
        ),
      ),
    );
    return ok == true;
  }

  Future<void> _next() async {
    if (_busy) return;
    final code = InviteCode.normalize(_controller.text);
    if (!InviteCode.isComplete(code)) {
      setState(() => _error = CircleStrings.codeIncomplete);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = ref.read(circleRepositoryProvider);
      final preview = await repo.previewInvite(code);
      if (!mounted) return;
      if (preview == null) {
        setState(
          () => _error = CircleStrings.error(CircleErrorKind.invalidCode),
        );
        return;
      }
      // Indikator berhenti selagi sheet konfirmasi terbuka.
      setState(() => _busy = false);
      if (!await _confirm(preview) || !mounted) return;
      setState(() => _busy = true);
      final id = await repo.joinCircle(code);
      if (id == null) {
        if (mounted) {
          setState(
            () => _error = CircleStrings.error(CircleErrorKind.invalidCode),
          );
        }
        return;
      }
      await refreshCirclesAndSelect(ref, id);
      if (mounted) context.pop();
    } on CircleError catch (e) {
      if (mounted) setState(() => _error = CircleStrings.error(e.kind));
    } catch (_) {
      if (mounted) {
        setState(() => _error = CircleStrings.error(CircleErrorKind.unknown));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.groupedBackground,
      navigationBar: const CupertinoNavigationBar(
        middle: Text(CircleStrings.joinTitle),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      CircleStrings.joinHint,
                      style: AppTextStyles.body(
                        context,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Semantics(
                      label: CircleStrings.codeLabel,
                      child: CupertinoTextField(
                        controller: _controller,
                        autofocus: true,
                        enabled: !_busy,
                        placeholder: CircleStrings.codePlaceholder,
                        textAlign: TextAlign.center,
                        textCapitalization: TextCapitalization.characters,
                        autocorrect: false,
                        enableSuggestions: false,
                        textInputAction: TextInputAction.done,
                        inputFormatters: const [InviteCodeFormatter()],
                        padding: const EdgeInsets.all(14),
                        style: AppTextStyles.title2(
                          context,
                          emphasized: true,
                        ).copyWith(letterSpacing: 4),
                        onChanged: (_) {
                          if (_error != null) setState(() => _error = null);
                        },
                        onSubmitted: (_) => _next(),
                      ),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            _error!,
                            style: AppTextStyles.footnote(
                              context,
                              color: AppColors.danger,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      label: CircleStrings.next,
                      busyLabel: CircleStrings.processing,
                      busy: _busy,
                      onPressed: _next,
                    ),
                    if (_canScan)
                      CupertinoButton(
                        minimumSize: const Size(44, 44),
                        onPressed: _busy ? null : _scan,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Symbols.qr_code_scanner, size: 20),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                CircleStrings.scanQr,
                                textAlign: TextAlign.center,
                                style: AppTextStyles.body(
                                  context,
                                  emphasized: true,
                                  color: AppColors.tint,
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
          ],
        ),
      ),
    );
  }
}
