import 'package:flutter/cupertino.dart';

import '../domain/circle_error.dart';
import 'circle_strings.dart';

/// Alert informasi untuk galat yang tidak punya tempat inline.
Future<void> showCircleError(BuildContext context, Object error) {
  final kind = error is CircleError ? error.kind : CircleErrorKind.unknown;
  return showCupertinoDialog<void>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: const Text(CircleStrings.errorTitle),
      content: Text(CircleStrings.error(kind)),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text(CircleStrings.ok),
        ),
      ],
    ),
  );
}

/// Alert konfirmasi destruktif. Batal bukan tombol bawaan (HIG). Mengembalikan
/// true bila pengguna menekan [action].
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
}) async {
  final ok = await showCupertinoDialog<bool>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text(CircleStrings.cancel),
        ),
        CupertinoDialogAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(action),
        ),
      ],
    ),
  );
  return ok == true;
}
