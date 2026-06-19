import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:hamsafar/core/i18n/l10n.dart';
import '../../domain/date_formatter.dart';
import '../../models/user_profile.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/buttons.dart';
import 'widgets/profile_widgets.dart';

/// The phone country codes the app supports — Tajikistan and Uzbekistan only.
enum _PhoneCountry {
  tajikistan('🇹🇯', '+992', 'Таджикистан'),
  uzbekistan('🇺🇿', '+998', 'Узбекистан');

  const _PhoneCountry(this.flag, this.dialCode, this.title);

  final String flag;
  final String dialCode;
  final String title;
}

/// Ported from `EditProfileView` in `ProfileViews.swift`.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late DateTime? _birthDate;
  late ProfileGender _gender;
  Uint8List? _avatarBytes;
  bool _avatarChanged = false;
  bool _isSaving = false;
  late _PhoneCountry _phoneCountry;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(currentUserProvider);
    _name = TextEditingController(text: profile.name);
    // Split a stored "+992 93…" into its country code + local part so the
    // picker reflects the saved country and the field shows only the number.
    final stored = profile.phoneNumber.trim();
    var country = _PhoneCountry.tajikistan;
    var local = stored;
    for (final c in _PhoneCountry.values) {
      if (stored.startsWith(c.dialCode)) {
        country = c;
        local = stored.substring(c.dialCode.length).trim();
        break;
      }
    }
    _phoneCountry = country;
    _phone = TextEditingController(text: local);
    _email = TextEditingController(text: profile.email);
    _birthDate = profile.birthDate;
    _gender = profile.gender ?? ProfileGender.male;
    _avatarBytes = profile.avatarBytes;
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final XFile? file;
    try {
      file = await picker.pickImage(
        source: ImageSource.gallery,
        // Avatars display at most ~156px — downscale at pick time so the upload
        // (and every later load in chats/trips) stays tiny (~20-40 KB).
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Не удалось открыть галерею.'))),
      );
      return;
    }
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _avatarBytes = bytes;
      _avatarChanged = true;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    // Users must be 18+, so the latest selectable birth date is exactly
    // 18 years ago — the picker can't offer anything younger.
    final latestAllowed = DateTime(now.year - 18, now.month, now.day);
    final initial = _birthDate ?? DateTime(now.year - 24, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(latestAllowed) ? latestAllowed : initial,
      firstDate: DateTime(1940),
      lastDate: latestAllowed,
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  bool _isValidEmail(String value) =>
      RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(value);

  int _ageInYears(DateTime birth) {
    final now = DateTime.now();
    var years = now.year - birth.year;
    if (now.month < birth.month ||
        (now.month == birth.month && now.day < birth.day)) {
      years--;
    }
    return years;
  }

  Future<void> _showValidationDialog(String message) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('Проверьте данные')),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(tr('Ок')),
          ),
        ],
      ),
    );
  }

  void _showCountryPicker() {
    final hs = context.hs;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: hs.cardBackground,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(tr('Выберите страну'), style: HSText.headline),
            ),
            for (final c in _PhoneCountry.values)
              ListTile(
                leading: Text(c.flag, style: const TextStyle(fontSize: 24)),
                title: Text(tr(c.title), style: HSText.subheadlineSemibold),
                trailing: Text(
                  c.dialCode,
                  style: HSText.subheadline.copyWith(
                    color: context.secondaryText,
                  ),
                ),
                onTap: () {
                  setState(() => _phoneCountry = c);
                  Navigator.of(sheetContext).pop();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      await _showValidationDialog(tr('Введите имя.'));
      return;
    }
    if (name.length > 50) {
      await _showValidationDialog(tr('Имя не должно превышать 50 символов.'));
      return;
    }
    final birth = _birthDate;
    if (birth != null && _ageInYears(birth) < 18) {
      await _showValidationDialog(tr('Возраст должен быть не меньше 18 лет.'));
      return;
    }
    final email = _email.text.trim();
    if (email.isNotEmpty && !_isValidEmail(email)) {
      await _showValidationDialog(tr('Введите корректный электронный адрес.'));
      return;
    }

    setState(() => _isSaving = true);
    final profile = ref.read(currentUserProvider);
    // Persist the number with its country code, e.g. "+992 934249394".
    final localPhone = _phone.text.trim();
    final fullPhone =
        localPhone.isEmpty ? '' : '${_phoneCountry.dialCode} $localPhone';
    String title = tr('Профиль обновлён');
    String message = tr('Изменения сохранены.');
    try {
      await ref.read(sessionProvider.notifier).updateProfile(
            profile.copyWith(
              name: name,
              phoneNumber: fullPhone,
              email: email,
              birthDate: _birthDate,
              gender: _gender,
              avatarBytes: _avatarChanged ? _avatarBytes : profile.avatarBytes,
            ),
          );
    } catch (e) {
      title = tr('Не удалось сохранить');
      message = e.toString();
    }
    if (!mounted) return;
    setState(() => _isSaving = false);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(tr('Ок')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(tr('Редактировать профиль'))),
      // Tap outside any field to dismiss the keyboard (the phone keyboard has
      // no "done" affordance and otherwise stays up over the Save button).
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Stack(
        fit: StackFit.expand,
        children: [
          SingleChildScrollView(
            // Left/right safe-area insets for landscape notch / Island (QA #93).
            padding: EdgeInsets.fromLTRB(
              20 + MediaQuery.paddingOf(context).left,
              20,
              20 + MediaQuery.paddingOf(context).right,
              120,
            ),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickAvatar,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    clipBehavior: Clip.none,
                    children: [
                      ProfileAvatarView(
                        initials: ref.watch(currentUserProvider).initials,
                        avatarBytes: _avatarChanged ? _avatarBytes : null,
                        avatarUrl: _avatarChanged
                            ? null
                            : ref.watch(currentUserProvider).avatarUrl,
                        size: 156,
                      ),
                      Positioned(
                        bottom: -18,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: hs.cardBackground,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: hs.stroke),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.camera_alt_outlined, size: 18),
                              const SizedBox(width: 8),
                              Text(tr('Изменить'), style: HSText.headline),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                SimpleProfileInput(
                  title: tr('Имя'),
                  child: TextField(
                    controller: _name,
                    inputFormatters: [LengthLimitingTextInputFormatter(50)],
                    decoration: InputDecoration.collapsed(
                      hintText: tr('Введите имя'),
                    ),
                    style: HSText.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 16),
                SimpleProfileInput(
                  title: tr('Телефон'),
                  child: Row(
                    children: [
                      // Country code picker (Tajikistan / Uzbekistan only).
                      GestureDetector(
                        onTap: _showCountryPicker,
                        behavior: HitTestBehavior.opaque,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${_phoneCountry.flag} ${_phoneCountry.dialCode}',
                              style: HSText.body.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Icon(
                              Icons.arrow_drop_down,
                              size: 20,
                              color: context.secondaryText,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(width: 1, height: 22, color: hs.stroke),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          // Local part only — digits + separators (the country
                          // code is chosen via the picker, so no "+" here).
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9()\-\s]'),
                            ),
                            LengthLimitingTextInputFormatter(15),
                          ],
                          decoration: InputDecoration.collapsed(
                            hintText: tr('Номер телефона'),
                          ),
                          style:
                              HSText.body.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SimpleProfileInput(
                  title: tr('Дата рождения'),
                  child: GestureDetector(
                    onTap: _pickBirthDate,
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      children: [
                        Text(
                          _birthDate == null
                              ? tr('Выберите дату')
                              : DateTextFormatter.dayMonthYear(_birthDate!),
                          style: HSText.body.copyWith(
                            fontWeight: FontWeight.w600,
                            color: _birthDate == null
                                ? context.secondaryText
                                : context.primaryText,
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.calendar_today, size: 18, color: hs.primary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SimpleProfileInput(
                  title: tr('Электронный адрес'),
                  child: TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration.collapsed(
                      hintText: tr('Введите электронный адрес'),
                    ),
                    style: HSText.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('Пол'), style: HSText.subheadlineSemibold),
                    const SizedBox(height: 8),
                    PopupMenuButton<ProfileGender>(
                      onSelected: (g) => setState(() => _gender = g),
                      itemBuilder: (_) => [
                        for (final g in ProfileGender.values)
                          PopupMenuItem(value: g, child: Text(tr(g.title))),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 18,
                        ),
                        decoration: BoxDecoration(
                          color: hs.secondarySurface,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          children: [
                            Text(
                              tr(_gender.title),
                              style: HSText.body.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: context.secondaryText,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        ),
      ),
      bottomNavigationBar: Container(
        color: hs.cardBackground,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Divider(height: 1, color: hs.stroke),
            Padding(
              // Lift the button above the keyboard (otherwise the phone-number
              // keyboard hides it and the user can't save) — see QA #26.
              padding: EdgeInsets.fromLTRB(
                20,
                14,
                20,
                12 +
                    MediaQuery.of(context).viewInsets.bottom +
                    MediaQuery.of(context).padding.bottom,
              ),
              child: PrimaryFilledButton(
                label: tr('Сохранить'),
                isLoading: _isSaving,
                onPressed: _isSaving ? null : _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
