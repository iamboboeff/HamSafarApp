import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hamsafar/core/i18n/l10n.dart';
import '../../models/user_profile.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/buttons.dart';
import '../../widgets/glass_card.dart';

/// Ported from `ReportUserView` in `ProfileViews.swift`. A simple form with a
/// reason picker + free-form details, submitted to the `contact--intake` Edge
/// function via `SupabaseService.submitUserReport`.
class ReportUserScreen extends ConsumerStatefulWidget {
  const ReportUserScreen({super.key, required this.reportedUser});

  final UserProfile reportedUser;

  @override
  ConsumerState<ReportUserScreen> createState() => _ReportUserScreenState();
}

class _ReportUserScreenState extends ConsumerState<ReportUserScreen> {
  static const _reasons = <String>[
    'Грубое поведение',
    'Не явился на поездку',
    'Подозрение в мошенничестве',
    'Спам в чате',
    'Другое',
  ];

  final _details = TextEditingController();
  String _reason = _reasons.first;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final details = _details.text.trim();
    if (details.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Опишите ситуацию перед отправкой.'))),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    String? error;
    try {
      await ref.read(supabaseServiceProvider).submitUserReport(
            reportedUser: widget.reportedUser,
            reason: _reason,
            details: details,
            profile: ref.read(currentUserProvider),
          );
    } catch (e) {
      error = e.toString();
    }
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(trf('Не удалось отправить: {error}', {'error': error})),
        ),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('Жалоба отправлена')),
        content: Text(
          tr(
            'Спасибо за сигнал. Мы рассмотрим обращение и свяжемся при необходимости.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(tr('Ок')),
          ),
        ],
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(tr('Пожаловаться'))),
      body: Stack(
        fit: StackFit.expand,
        children: [
          SingleChildScrollView(
            // Left/right safe-area insets for landscape notch / Island (QA #93).
            padding: EdgeInsets.fromLTRB(
              20 + MediaQuery.paddingOf(context).left,
              20,
              20 + MediaQuery.paddingOf(context).right,
              32,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('Жалоба на пользователя'), style: HSText.headline),
                      const SizedBox(height: 8),
                      Text(
                        trf(
                          'Опишите ситуацию с пользователем {name}. '
                          'Мы рассмотрим обращение в течение нескольких дней.',
                          {'name': widget.reportedUser.name},
                        ),
                        style: HSText.subheadline.copyWith(
                          color: context.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: hs.cardBackground,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: hs.stroke),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _reason,
                            isExpanded: true,
                            items: [
                              for (final r in _reasons)
                                DropdownMenuItem(value: r, child: Text(tr(r))),
                            ],
                            onChanged: (v) =>
                                setState(() => _reason = v ?? _reasons.first),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _details,
                        minLines: 4,
                        maxLines: 8,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: tr(
                            'Опишите, что произошло — это поможет принять меры.',
                          ),
                          filled: true,
                          fillColor: hs.secondarySurface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: hs.stroke),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: hs.stroke),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                PrimaryFilledButton(
                  isLoading: _isSubmitting,
                  onPressed: _isSubmitting ? null : _submit,
                  label: tr('Отправить жалобу'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
