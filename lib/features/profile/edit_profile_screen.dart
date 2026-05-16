import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/date_formatter.dart';
import '../../models/user_profile.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/app_backdrop.dart';
import '../../widgets/buttons.dart';
import 'widgets/profile_widgets.dart';

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

  @override
  void initState() {
    super.initState();
    final profile = ref.read(currentUserProvider);
    _name = TextEditingController(text: profile.name);
    _phone = TextEditingController(text: profile.phoneNumber);
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
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть галерею.')),
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
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 24, now.month, now.day),
      firstDate: DateTime(1940),
      lastDate: now,
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final profile = ref.read(currentUserProvider);
    String title = 'Профиль обновлён';
    String message = 'Изменения сохранены.';
    try {
      await ref.read(sessionProvider.notifier).updateProfile(
            profile.copyWith(
              name: _name.text.trim(),
              phoneNumber: _phone.text.trim(),
              email: _email.text.trim(),
              birthDate: _birthDate,
              gender: _gender,
              avatarBytes: _avatarChanged ? _avatarBytes : profile.avatarBytes,
            ),
          );
    } catch (e) {
      title = 'Не удалось сохранить';
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
            child: const Text('Ок'),
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
      appBar: AppBar(title: const Text('Редактировать профиль')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AppBackdrop(),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
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
                        avatarBytes: _avatarBytes,
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
                              Text('Изменить', style: HSText.headline),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  _phone.text,
                  textAlign: TextAlign.center,
                  style: HSText.title3,
                ),
                const SizedBox(height: 22),
                SimpleProfileInput(
                  title: 'Имя',
                  child: TextField(
                    controller: _name,
                    decoration: const InputDecoration.collapsed(
                      hintText: 'Введите имя',
                    ),
                    style: HSText.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 16),
                SimpleProfileInput(
                  title: 'Телефон',
                  child: TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration.collapsed(
                      hintText: 'Введите номер телефона',
                    ),
                    style: HSText.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 16),
                SimpleProfileInput(
                  title: 'Дата рождения',
                  child: GestureDetector(
                    onTap: _pickBirthDate,
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      children: [
                        Text(
                          _birthDate == null
                              ? 'Выберите дату'
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
                  title: 'Электронный адрес',
                  child: TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration.collapsed(
                      hintText: 'Введите электронный адрес',
                    ),
                    style: HSText.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Пол', style: HSText.subheadlineSemibold),
                    const SizedBox(height: 8),
                    PopupMenuButton<ProfileGender>(
                      onSelected: (g) => setState(() => _gender = g),
                      itemBuilder: (_) => [
                        for (final g in ProfileGender.values)
                          PopupMenuItem(value: g, child: Text(g.title)),
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
                              _gender.title,
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
      bottomNavigationBar: Container(
        color: hs.cardBackground,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Divider(height: 1, color: hs.stroke.withValues(alpha: 0.9)),
            Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                14,
                20,
                12 + MediaQuery.of(context).padding.bottom,
              ),
              child: PrimaryFilledButton(
                label: 'Сохранить',
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
