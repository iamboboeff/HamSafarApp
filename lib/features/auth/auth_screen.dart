import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase/supabase_service.dart';
import '../../domain/date_formatter.dart';
import '../../models/residence_country.dart';
import '../../models/user_profile.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/buttons.dart';
import '../../widgets/glass_card.dart';
import '../profile/widgets/profile_widgets.dart';
import 'widgets/auth_field.dart';

/// Ported from `AuthFlowMode` in `AuthenticationViews.swift`.
enum AuthFlowMode {
  signIn('Вход'),
  register('Регистрация');

  const AuthFlowMode(this.title);
  final String title;
}

/// Ported from `AuthenticationFlowView` in `AuthenticationViews.swift`.
///
/// Sign-in / registration go through the real Supabase auth via
/// [SupabaseService]; on success the session is applied and, for
/// registration, the entered profile details are saved to the backend.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  AuthFlowMode _flow = AuthFlowMode.signIn;

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _otp = TextEditingController();

  late DateTime _birthDate = DateTime(
    DateTime.now().year - 24,
    DateTime.now().month,
    DateTime.now().day,
  );
  ProfileGender _gender = ProfileGender.male;

  bool _hasSentOtp = false;
  bool _isLoading = false;
  int _resendCountdown = 0;
  Timer? _resendTimer;
  String? _statusMessage;
  String? _errorMessage;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _otp.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  DateTime get _minBirthDate => DateTime(
    DateTime.now().year - 16,
    DateTime.now().month,
    DateTime.now().day,
  );

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendCountdown = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendCountdown--;
        if (_resendCountdown <= 0) timer.cancel();
      });
    });
  }

  Future<void> _handleSignIn() async {
    setState(() {
      _errorMessage = null;
      _statusMessage = null;
      _isLoading = true;
    });
    try {
      final data = await ref
          .read(supabaseServiceProvider)
          .signInWithEmailPassword(
            email: _email.text,
            password: _password.text,
          );
      ref.read(sessionProvider.notifier).applySession(data);
      if (mounted) Navigator.of(context).pop();
    } on SupabaseServiceError catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRegister() async {
    setState(() {
      _errorMessage = null;
      _statusMessage = null;
    });

    final name = _name.text.trim();
    final email = _email.text.trim().toLowerCase();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Укажите имя.');
      return;
    }
    if (email.isEmpty) {
      setState(() => _errorMessage = 'Укажите email.');
      return;
    }
    if (_password.text.length < 6) {
      setState(() => _errorMessage = 'Пароль должен быть минимум 6 символов.');
      return;
    }
    if (_password.text != _confirmPassword.text) {
      setState(() => _errorMessage = 'Пароли не совпадают.');
      return;
    }
    if (_birthDate.isAfter(_minBirthDate)) {
      setState(() => _errorMessage = 'Регистрация доступна с 16 лет.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final service = ref.read(supabaseServiceProvider);
      if (_hasSentOtp) {
        final data = await service.verifyEmailSignupOtp(
          email: email,
          token: _otp.text,
        );
        // Persist the entered profile details to the backend.
        final updated = await service.saveProfile(
          data.profile.copyWith(
            name: name,
            email: email,
            gender: _gender,
            birthDate: _birthDate,
            countryOfResidence: data.profile.countryOfResidence ??
                ResidenceCountry.tajikistan,
          ),
        );
        ref.read(sessionProvider.notifier).applySession(updated);
        if (mounted) Navigator.of(context).pop();
      } else {
        await service.signUpWithEmailPassword(
          email: email,
          password: _password.text,
        );
        setState(() {
          _hasSentOtp = true;
          _statusMessage = 'Код отправлен на $email.';
        });
        _startResendCountdown();
      }
    } on SupabaseServiceError catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendOtp() async {
    if (_resendCountdown != 0) return;
    setState(() {
      _errorMessage = null;
      _statusMessage = null;
      _isLoading = true;
    });
    try {
      await ref
          .read(supabaseServiceProvider)
          .resendEmailSignupOtp(_email.text.trim().toLowerCase());
      setState(() => _statusMessage = 'Новый код отправлен.');
      _startResendCountdown();
    } on SupabaseServiceError catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate,
      firstDate: DateTime(1940),
      lastDate: _minBirthDate,
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        title: const Text('Войти'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [hs.cardBackground, hs.tint, hs.background],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, kToolbarHeight + 12, 20, 40),
            child: AbsorbPointer(
              absorbing: _isLoading,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'HamSafar',
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Поездки между городами без лишних звонков и долгих '
                    'согласований.',
                    style: HSText.subheadline.copyWith(
                      color: context.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 24),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        HSSegmentedControl<AuthFlowMode>(
                          items: AuthFlowMode.values,
                          selected: _flow,
                          titleOf: (m) => m.title,
                          onSelect: (m) => setState(() {
                            _flow = m;
                            _errorMessage = null;
                            _statusMessage = null;
                          }),
                        ),
                        const SizedBox(height: 18),
                        if (_flow == AuthFlowMode.signIn)
                          ..._signInFields()
                        else
                          ..._registerFields(),
                        if (_statusMessage != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            _statusMessage!,
                            style: HSText.footnote.copyWith(
                              color: Colors.green.withValues(alpha: 0.92),
                            ),
                          ),
                        ],
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            _errorMessage!,
                            style: HSText.footnote.copyWith(
                              color: Colors.red.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _signInFields() {
    return [
      AuthField(
        title: 'Email',
        controller: _email,
        icon: Icons.mail_outline,
        keyboardType: TextInputType.emailAddress,
      ),
      const SizedBox(height: 14),
      AuthField(
        title: 'Пароль',
        controller: _password,
        icon: Icons.lock_outline,
        isSecure: true,
      ),
      const SizedBox(height: 18),
      PrimaryFilledButton(
        label: 'Войти',
        isLoading: _isLoading,
        onPressed: _isLoading ? null : _handleSignIn,
      ),
    ];
  }

  List<Widget> _registerFields() {
    return [
      AuthField(title: 'Имя', controller: _name, icon: Icons.person_outline),
      const SizedBox(height: 14),
      AuthDateField(
        title: 'Дата рождения',
        icon: Icons.calendar_today,
        value: DateTextFormatter.dayMonthYear(_birthDate),
        onTap: _pickBirthDate,
      ),
      const SizedBox(height: 14),
      Text(
        'Пол',
        style: HSText.captionSemibold.copyWith(color: context.secondaryText),
      ),
      const SizedBox(height: 8),
      HSSegmentedControl<ProfileGender>(
        items: ProfileGender.values,
        selected: _gender,
        titleOf: (g) => g.title,
        onSelect: (g) => setState(() => _gender = g),
      ),
      const SizedBox(height: 14),
      AuthField(
        title: 'Email',
        controller: _email,
        icon: Icons.mail_outline,
        keyboardType: TextInputType.emailAddress,
      ),
      const SizedBox(height: 14),
      AuthField(
        title: 'Пароль',
        controller: _password,
        icon: Icons.lock_outline,
        isSecure: true,
      ),
      const SizedBox(height: 14),
      AuthField(
        title: 'Повторите пароль',
        controller: _confirmPassword,
        icon: Icons.lock_reset,
        isSecure: true,
      ),
      if (_hasSentOtp) ...[
        const SizedBox(height: 14),
        AuthField(
          title: 'Код из письма',
          controller: _otp,
          icon: Icons.tag,
          keyboardType: TextInputType.number,
        ),
      ],
      const SizedBox(height: 18),
      PrimaryFilledButton(
        label: _hasSentOtp ? 'Завершить регистрацию' : 'Получить код',
        isLoading: _isLoading,
        onPressed: _isLoading ? null : _handleRegister,
      ),
      if (_hasSentOtp) ...[
        const SizedBox(height: 12),
        Center(
          child: GestureDetector(
            onTap: _resendCountdown == 0 && !_isLoading ? _resendOtp : null,
            child: Text(
              _resendCountdown == 0
                  ? 'Отправить код повторно'
                  : 'Повторная отправка через $_resendCountdown сек',
              style: HSText.footnote.copyWith(
                fontWeight: FontWeight.w600,
                color: _resendCountdown == 0
                    ? context.hs.primary
                    : context.secondaryText,
              ),
            ),
          ),
        ),
      ],
    ];
  }
}
