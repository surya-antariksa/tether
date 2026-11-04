import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/circle_providers.dart';
import '../domain/circle_error.dart';
import 'circle_strings.dart';

/// Form buat Circle: nama 1..40 karakter.
class CreateCirclePage extends ConsumerStatefulWidget {
  const CreateCirclePage({super.key});

  @override
  ConsumerState<CreateCirclePage> createState() => _CreateCirclePageState();
}

class _CreateCirclePageState extends ConsumerState<CreateCirclePage> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = CircleStrings.nameEmpty);
      return;
    }
    if (name.characters.length > 40) {
      setState(() => _error = CircleStrings.nameTooLong);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = await ref.read(circleRepositoryProvider).createCircle(name);
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
        middle: Text(CircleStrings.createTitle),
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
                    Semantics(
                      label: CircleStrings.nameLabel,
                      child: CupertinoTextField(
                        controller: _controller,
                        autofocus: true,
                        enabled: !_busy,
                        placeholder: CircleStrings.namePlaceholder,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.done,
                        padding: const EdgeInsets.all(14),
                        onChanged: (_) {
                          if (_error != null) setState(() => _error = null);
                        },
                        onSubmitted: (_) => _submit(),
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
                      label: CircleStrings.createAction,
                      busyLabel: CircleStrings.processing,
                      busy: _busy,
                      onPressed: _submit,
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
