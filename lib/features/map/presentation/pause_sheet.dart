import 'package:flutter/cupertino.dart';

import 'map_strings.dart';

/// Pilihan durasi jeda. [minutes] null = sampai dinyalakan lagi.
class PauseChoice {
  const PauseChoice(this.minutes);

  final int? minutes;
}

/// Action sheet pilihan durasi jeda (docs/08 bagian 6.5). Mengembalikan null
/// bila dibatalkan.
Future<PauseChoice?> showPauseSheet(BuildContext context) {
  return showCupertinoModalPopup<PauseChoice>(
    context: context,
    builder: (ctx) => CupertinoActionSheet(
      title: const Text(MapStrings.pauseSheetTitle),
      message: const Text(MapStrings.pauseSheetMessage),
      actions: [
        CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(const PauseChoice(15)),
          child: const Text(MapStrings.pause15),
        ),
        CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(const PauseChoice(60)),
          child: const Text(MapStrings.pause60),
        ),
        CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(const PauseChoice(null)),
          child: const Text(MapStrings.pauseUntilResume),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.of(ctx).pop(),
        child: const Text(MapStrings.cancel),
      ),
    ),
  );
}

/// Pemilih Circle (bila pengguna punya lebih dari satu). Mengembalikan id
/// Circle terpilih, atau null bila dibatalkan.
Future<String?> showCirclePicker(
  BuildContext context, {
  required List<({String id, String name})> circles,
  required String currentId,
}) {
  return showCupertinoModalPopup<String>(
    context: context,
    builder: (ctx) => CupertinoActionSheet(
      title: const Text(MapStrings.circlePickerTitle),
      actions: [
        for (final c in circles)
          CupertinoActionSheetAction(
            isDefaultAction: c.id == currentId,
            onPressed: () => Navigator.of(ctx).pop(c.id),
            child: Text(c.name),
          ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.of(ctx).pop(),
        child: const Text(MapStrings.circlePickerCancel),
      ),
    ),
  );
}
