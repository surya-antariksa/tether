import 'package:flutter/cupertino.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/member_colors.dart';
import '../domain/profile.dart';

/// Menampilkan sheet modal ubah profil publik Circle dan warna penanda peta.
Future<bool?> showEditProfileSheet(
  BuildContext context, {
  required Profile profile,
  required Future<void> Function({String? displayName, String? color}) onSave,
}) {
  return showCupertinoModalPopup<bool>(
    context: context,
    builder: (_) => EditProfileSheet(profile: profile, onSave: onSave),
  );
}

class EditProfileSheet extends StatefulWidget {
  const EditProfileSheet({
    super.key,
    required this.profile,
    required this.onSave,
  });

  final Profile profile;
  final Future<void> Function({String? displayName, String? color}) onSave;

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  late final TextEditingController _nameController;
  late String _selectedHex;
  late String _selectedColorName;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.displayName);
    _selectedHex = widget.profile.color.toUpperCase();

    final found = MemberColors.palette.where(
      (c) => c.hex.toUpperCase() == _selectedHex,
    );
    _selectedColorName = found.isNotEmpty ? found.first.name : 'Kustom';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _getInitial() {
    final text = _nameController.text.trim();
    if (text.isEmpty) {
      final old = widget.profile.displayName.trim();
      return old.isNotEmpty ? old[0].toUpperCase() : '?';
    }
    return text[0].toUpperCase();
  }

  Future<void> _handleSave() async {
    final trimmed = _nameController.text.trim();
    if (trimmed.isEmpty) {
      setState(() => _error = 'Nama tidak boleh kosong.');
      return;
    }
    if (trimmed.length > 24) {
      setState(() => _error = 'Nama maksimal 24 karakter.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final nameChanged = trimmed != widget.profile.displayName;
      final colorChanged =
          _selectedHex.toUpperCase() != widget.profile.color.toUpperCase();

      if (nameChanged || colorChanged) {
        await widget.onSave(
          displayName: nameChanged ? trimmed : null,
          color: colorChanged ? _selectedHex : null,
        );
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Gagal menyimpan perubahan. Coba lagi.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = MemberColors.toColor(_selectedHex);
    final isDark = AppColors.isDark(context);

    return DefaultTextStyle(
      style: CupertinoTheme.of(context).textTheme.textStyle,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: CupertinoDynamicColor.resolve(
                AppColors.groupedBackground,
                context,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              border: Border(
                top: BorderSide(
                  color: CupertinoDynamicColor.resolve(
                    AppColors.separator,
                    context,
                  ),
                  width: 0.5,
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Drag notch
                    Center(
                      child: Container(
                        width: 48,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: CupertinoDynamicColor.resolve(
                            CupertinoColors.systemGrey3,
                            context,
                          ).withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),

                    // Header row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ubah Profil Publik Circle',
                                style: AppTextStyles.title3(
                                  context,
                                  emphasized: true,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Pengaturan identitas visual Anda di keluarga',
                                style: AppTextStyles.footnote(
                                  context,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(32, 32),
                          borderRadius: BorderRadius.circular(99),
                          color: CupertinoDynamicColor.resolve(
                            AppColors.groupedItemBackground,
                            context,
                          ),
                          onPressed: () => Navigator.of(context).pop(false),
                          child: Icon(
                            Symbols.close,
                            size: 16,
                            color: AppColors.textSecondary.resolveFrom(context),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Live Avatar Map Pin HUD Preview Bento
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 20,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: CupertinoDynamicColor.resolve(
                          AppColors.groupedItemBackground,
                          context,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: activeColor.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Center(
                            child: SizedBox(
                              width: 104,
                              height: 104,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Outer halo glow
                                  Container(
                                    width: 96,
                                    height: 96,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: activeColor.withValues(
                                        alpha: isDark ? 0.12 : 0.08,
                                      ),
                                    ),
                                  ),
                                  // Mid aura glow
                                  Container(
                                    width: 78,
                                    height: 78,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: activeColor.withValues(
                                        alpha: isDark ? 0.22 : 0.15,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: activeColor.withValues(
                                            alpha: 0.35,
                                          ),
                                          blurRadius: 18,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Center Pin
                                  Container(
                                    width: 62,
                                    height: 62,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isDark
                                          ? AppColors.background.resolveFrom(
                                              context,
                                            )
                                          : CupertinoColors.white,
                                      border: Border.all(
                                        color: activeColor,
                                        width: 2.8,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        _getInitial(),
                                        style: TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.w800,
                                          color: isDark
                                              ? CupertinoColors.white
                                              : CupertinoColors.black,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // GPS Status Badge
                                  Positioned(
                                    right: 18,
                                    bottom: 18,
                                    child: Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isDark
                                            ? AppColors.background.resolveFrom(
                                                context,
                                              )
                                            : CupertinoColors.white,
                                        border: Border.all(
                                          color: CupertinoColors.systemGrey4,
                                          width: 1,
                                        ),
                                      ),
                                      child: Center(
                                        child: Icon(
                                          Symbols.near_me,
                                          size: 11,
                                          color: AppColors.success.resolveFrom(
                                            context,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),

                          // Pill tag
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: activeColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(
                                color: activeColor.withValues(alpha: 0.3),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: activeColor,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Pratinjau tampilan Anda di peta',
                                  style: AppTextStyles.caption1(
                                    context,
                                    color: isDark
                                        ? AppColors.textPrimary.resolveFrom(
                                            context,
                                          )
                                        : CupertinoColors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Muncul di radar peta semua anggota Circle real-time',
                            style: AppTextStyles.caption2(
                              context,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Input Field: Nama Tampilan
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Nama Tampilan',
                          style: AppTextStyles.subhead(
                            context,
                            emphasized: true,
                          ),
                        ),
                        Text(
                          '${_nameController.text.length}/24',
                          style: AppTextStyles.caption1(
                            context,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: CupertinoDynamicColor.resolve(
                          AppColors.groupedItemBackground,
                          context,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _error != null
                              ? AppColors.danger.resolveFrom(context)
                              : CupertinoDynamicColor.resolve(
                                  AppColors.separator,
                                  context,
                                ),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Icon(
                              Symbols.person_add,
                              size: 20,
                              color: AppColors.textSecondary.resolveFrom(
                                context,
                              ),
                            ),
                          ),
                          Expanded(
                            child: CupertinoTextField(
                              controller: _nameController,
                              maxLength: 24,
                              placeholder: 'Ketik nama Anda di Circle',
                              decoration: null,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              style: AppTextStyles.body(context),
                              onChanged: (_) => setState(() => _error = null),
                            ),
                          ),
                          if (_nameController.text.isNotEmpty)
                            CupertinoButton(
                              padding: const EdgeInsets.only(right: 12),
                              minimumSize: const Size(28, 28),
                              onPressed: () {
                                _nameController.clear();
                                setState(() => _error = null);
                              },
                              child: Icon(
                                Symbols.cancel,
                                size: 18,
                                color: AppColors.textTertiary.resolveFrom(
                                  context,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _error!,
                        style: AppTextStyles.footnote(
                          context,
                          color: AppColors.danger,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Symbols.info,
                          size: 14,
                          color: AppColors.textSecondary.resolveFrom(context),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            'Nama ini dilihat oleh semua anggota dalam Circle keluarga.',
                            style: AppTextStyles.caption2(
                              context,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Marker Color Picker Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Pilih Warna Penanda di Peta',
                            style: AppTextStyles.subhead(
                              context,
                              emphasized: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _selectedColorName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: activeColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final chip in MemberColors.palette)
                            Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: _ColorChipButton(
                                chip: chip,
                                isSelected:
                                    _selectedHex.toUpperCase() ==
                                    chip.hex.toUpperCase(),
                                onTap: () {
                                  setState(() {
                                    _selectedHex = chip.hex.toUpperCase();
                                    _selectedColorName = chip.name;
                                  });
                                },
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Privacy & Realtime Sync Notice
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: CupertinoDynamicColor.resolve(
                          AppColors.groupedItemBackground,
                          context,
                        ).withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: CupertinoDynamicColor.resolve(
                            AppColors.separator,
                            context,
                          ).withValues(alpha: 0.5),
                          width: 0.6,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Symbols.sync,
                            size: 16,
                            color: AppColors.tint.resolveFrom(context),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Perubahan nama dan warna akan langsung terupdate ke semua layar peta Circle.',
                              style: AppTextStyles.caption1(
                                context,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Save Action Button
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      color: AppColors.tint.resolveFrom(context),
                      borderRadius: BorderRadius.circular(99),
                      onPressed: _saving ? null : _handleSave,
                      child: Container(
                        height: 50,
                        alignment: Alignment.center,
                        child: _saving
                            ? CupertinoActivityIndicator(
                                color: AppColors.onTint.resolveFrom(context),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Symbols.check_circle,
                                    size: 20,
                                    color: AppColors.onTint.resolveFrom(
                                      context,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Simpan Perubahan',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.onTint.resolveFrom(
                                        context,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Cancel Action Button
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      borderRadius: BorderRadius.circular(99),
                      color: CupertinoDynamicColor.resolve(
                        AppColors.groupedItemBackground,
                        context,
                      ),
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: Container(
                        height: 44,
                        alignment: Alignment.center,
                        child: Text(
                          'Batal',
                          style: AppTextStyles.body(
                            context,
                            color: AppColors.textPrimary,
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
    );
  }
}

class _ColorChipButton extends StatelessWidget {
  const _ColorChipButton({
    required this.chip,
    required this.isSelected,
    required this.onTap,
  });

  final MarkerColorChip chip;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = MemberColors.toColor(chip.hex);
    return Semantics(
      button: true,
      selected: isSelected,
      label: 'Warna ${chip.name}',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: isSelected
                ? Border.all(color: CupertinoColors.white, width: 2.5)
                : null,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.65),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: isSelected
              ? Center(
                  child: Icon(
                    Symbols.check,
                    size: 18,
                    color: MemberColors.onColor(chip.hex),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
