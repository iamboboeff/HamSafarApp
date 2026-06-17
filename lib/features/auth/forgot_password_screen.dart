import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/net_status.dart';
import '../../core/supabase/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/buttons.dart';
import '../../widgets/glass_card.dart';
import 'widgets/auth_field.dart';

/// Password-recovery flow (QA #67): request a code by email, then set a new
/// password. Mirrors the OTP-based signup flow. On success the recovery session
/// is cleared and the user returns to the sign-in screen to log in with the new
/// password; the entered email is passed back so it can be pre-filled.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  late final _email = TextEditingController(text: widget.initialEmail ?? '');
  final _otp = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _otpFocus = FocusNode();

  bool _codeSent = false;
  bool _isLoading = false;
  int _resendCountdown = 0;
  Timer? _resendTimer;
  String? _statusMessage;
  String? _errorMessage;

  @override
  void dispose() {
    _email.dispose();
    _otp.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _otpFocus.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

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

  Future<void> _sendCode({required bool isResend}) async {
    final email = _email.text.trim().toLowerCase();
    if (email.isEmpty) {
      setState(() => _errorMessage = 'Укажите email.');
      return;
    }
    setState(() {
      _errorMessage = null;
      _statusMessage = null;
      _isLoading = true;
    });
    try {
      await ref.read(supabaseServiceProvider).sendPasswordRecovery(email);
      setState(() {
        _codeSent = true;
        _statusMessage =
            isResend ? 'Новый код отправлен.' : 'Код отправлен на $email.';
      });
      _startResendCountdown();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _otpFocus.requestFocus();
      });
    } on SupabaseServiceError catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = isOfflineError(e)
          ? offlineMessage
          : 'Не удалось отправить код. Попробуйте ещё раз.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitNewPassword() async {
    setState(() {
      _errorMessage = null;
      _statusMessage = null;
    });
    if (_otp.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Введите код из письма.');
      return;
    }
    if (_password.text.length < 6) {
      setState(() => _errorMessage = 'Пароль должен быть минимум 6 символов.');
      return;
    }
    if (_password.text != _password.text.trim()) {
      setState(() => _errorMessage =
          'Пароль не должен начинаться или заканчиваться пробелом.');
      return;
    }
    if (_password.text != _confirmPassword.text) {
      setState(() => _errorMessage = 'Пароли не совпадают.');
      return;
    }

    setState(() => _isLoading = true);
    final email = _email.text.trim().toLowerCase();
    try {
      final service = ref.read(supabaseServiceProvider);
      await service.verifyPasswordRecoveryOtp(email: email, token: _otp.text);
      await service.updatePassword(_password.text);
      // Clear the short-lived recovery session so the user logs in cleanly with
      // the new password.
      await service.signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Пароль обновлён. Войдите с новым паролем.'),
        ),
      );
      Navigator.of(context).pop(email);
    } on SupabaseServiceError catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = isOfflineError(e)
          ? offlineMessage
          : 'Не удалось обновить пароль. Попробуйте ещё раз.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
        title: const Text('Восстановление пароля'),
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
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            child: AbsorbPointer(
              absorbing: _isLoading,
              child: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _codeSent
                          ? 'Введите код из письма и придумайте новый пароль.'
                          : 'Укажите email — мы отправим код для сброса пароля.',
                      style: HSText.subheadline.copyWith(
                        color: context.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 18),
                    AuthField(
                      title: 'Email',
                      controller: _email,
                      icon: Icons.mail_outline,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    if (_codeSent) ...[
                      const SizedBox(height: 14),
                      AuthField(
                        title: 'Код из письма',
                        controller: _otp,
                        focusNode: _otpFocus,
                        icon: Icons.tag,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 14),
                      AuthField(
                        title: 'Новый пароль',
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
                    ],
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
                    const SizedBox(height: 18),
                    PrimaryFilledButton(
                      label: _codeSent ? 'Сохранить пароль' : 'Отправить код',
                      isLoading: _isLoading,
                      onPressed: _isLoading
                          ? null
                          : (_codeSent
                              ? _submitNewPassword
                              : () => _sendCode(isResend: false)),
                    ),
                    if (_codeSent) ...[
                      const SizedBox(height: 12),
                      Center(
                        child: GestureDetector(
                          onTap: _resendCountdown == 0 && !_isLoading
                              ? () => _sendCode(isResend: true)
                              : null,
                          child: Text(
                            _resendCountdown == 0
                                ? 'Отправить код повторно'
                                : 'Повторная отправка через $_resendCountdown сек',
                            style: HSText.footnote.copyWith(
                              fontWeight: FontWeight.w600,
                              color: _resendCountdown == 0
                                  ? hs.primary
                                  : context.secondaryText,
                            ),
                          ),
                        ),
                      ),
                    ],
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
