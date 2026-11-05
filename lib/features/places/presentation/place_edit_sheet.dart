import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/place_providers.dart';
import '../domain/place.dart';
import '../domain/place_error.dart';
import 'place_form.dart';
import 'place_strings.dart';

/// Lembar ubah nama/radius dan hapus. Mengembalikan true bila ada perubahan
/// (ubah atau hapus berhasil).
Future<bool?> showPlaceEditSheet(BuildContext context, Place place) =>
    showCupertinoModalPopup<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => PlaceEditSheet(place: place),
    );

class PlaceEditSheet extends ConsumerStatefulWidget {
  const PlaceEditSheet({super.key, required this.place});

  final Place place;

  @override
  ConsumerState<PlaceEditSheet> createState() => _PlaceEditSheetState();
}

class _PlaceEditSheetState extends ConsumerState<PlaceEditSheet> {
  late final _name = TextEditingController(text: widget.place.name);
  late int _radius = widget.place.radiusM;
  bool _saving = false;
  bool _deleting = false;
  String? _error;

  bool get _busy => _saving || _deleting;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final issue = validatePlaceName(_name.text);
    if (issue != null) {
      setState(() => _error = PlaceStrings.nameIssue(issue));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(placesProvider(widget.place.circleId).notifier)
          .edit(widget.place.id, name: _name.text.trim(), radiusM: _radius);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (_busy) return;
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text(PlaceStrings.deleteConfirmTitle),
        content: Text(PlaceStrings.deleteConfirmMessage(widget.place.name)),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(PlaceStrings.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(PlaceStrings.delete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await ref
          .read(placesProvider(widget.place.circleId).notifier)
          .delete(widget.place.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  String _message(Object e) =>
      PlaceStrings.error(e is PlaceError ? e.kind : PlaceErrorKind.unknown);

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: DefaultTextStyle(
        style: CupertinoTheme.of(context).textTheme.textStyle,
        child: Semantics(
          scopesRoute: true,
          explicitChildNodes: true,
          label: PlaceStrings.editTitle,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.background.resolveFrom(context),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: SafeArea(
              top: false,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: media.size.height * 0.9),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Semantics(
                              header: true,
                              child: Text(
                                PlaceStrings.editTitle,
                                style: AppTextStyles.headline(context),
                              ),
                            ),
                          ),
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(44, 44),
                            onPressed: _busy
                                ? null
                                : () => Navigator.of(context).pop(false),
                            child: const Text(PlaceStrings.cancel),
                          ),
                        ],
                      ),
                      PlaceForm(
                        controller: _name,
                        radiusM: _radius,
                        enabled: !_busy,
                        error: _error,
                        onRadiusChanged: (r) => setState(() => _radius = r),
                        onNameChanged: () {
                          if (_error != null) setState(() => _error = null);
                        },
                        onSubmitted: _save,
                      ),
                      const SizedBox(height: 16),
                      PrimaryButton(
                        label: PlaceStrings.save,
                        busyLabel: PlaceStrings.saving,
                        busy: _saving,
                        onPressed: _busy ? null : _save,
                      ),
                      const SizedBox(height: 4),
                      Semantics(
                        button: true,
                        enabled: !_busy,
                        label: _deleting
                            ? PlaceStrings.deleting
                            : PlaceStrings.delete,
                        excludeSemantics: true,
                        onTap: _busy ? null : _delete,
                        child: CupertinoButton(
                          minimumSize: const Size(44, 44),
                          onPressed: _busy ? null : _delete,
                          child: Text(
                            PlaceStrings.delete,
                            style: AppTextStyles.body(
                              context,
                              color: _busy
                                  ? CupertinoColors.tertiaryLabel
                                  : AppColors.danger,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
