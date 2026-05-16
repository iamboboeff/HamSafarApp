import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/app_backdrop.dart';
import '../../widgets/buttons.dart';
import '../../widgets/glass_card.dart';

/// Ported from `HelpGuideItem` in `ProfileViews.swift`.
class HelpGuideItem {
  const HelpGuideItem({
    required this.title,
    required this.description,
    required this.icon,
  });
  final String title;
  final String description;
  final IconData icon;
}

/// Ported from `HelpGuideView` in `ProfileViews.swift`.
class HelpGuideScreen extends StatelessWidget {
  const HelpGuideScreen({
    super.key,
    required this.title,
    required this.accent,
    required this.heroTitle,
    required this.heroSubtitle,
    required this.items,
  });

  final String title;
  final Color accent;
  final String heroTitle;
  final String heroSubtitle;
  final List<HelpGuideItem> items;

  /// The two guides referenced from the Profile screen.
  static HelpGuideScreen passengers(BuildContext context) => HelpGuideScreen(
    title: 'Пассажирам',
    accent: context.hs.passenger,
    heroTitle: 'Как бронировать поездки без лишних шагов',
    heroSubtitle: 'Поиск, бронирование и общение с водителем в одном месте.',
    items: const [
      HelpGuideItem(
        title: 'Выберите маршрут',
        description:
            'Укажите город отправления, назначения и дату, чтобы увидеть подходящие поездки.',
        icon: Icons.search,
      ),
      HelpGuideItem(
        title: 'Проверьте водителя',
        description:
            'Смотрите рейтинг, отзывы, модель машины и количество свободных мест.',
        icon: Icons.star_outline,
      ),
      HelpGuideItem(
        title: 'Забронируйте место',
        description:
            'Подтвердите поездку и сразу переходите в чат для согласования деталей.',
        icon: Icons.check_circle_outline,
      ),
      HelpGuideItem(
        title: 'Следите за поездкой',
        description:
            'Активные бронирования и история всегда доступны в разделе «Мои поездки».',
        icon: Icons.directions_car_outlined,
      ),
    ],
  );

  static HelpGuideScreen drivers(BuildContext context) => HelpGuideScreen(
    title: 'Водителям',
    accent: context.hs.primary,
    heroTitle: 'Как быстро опубликовать поездку',
    heroSubtitle: 'Маршрут, места, цена и заявки пассажиров под рукой.',
    items: const [
      HelpGuideItem(
        title: 'Добавьте маршрут',
        description:
            'Укажите откуда и куда вы едете, затем выберите дату и время отправления.',
        icon: Icons.alt_route,
      ),
      HelpGuideItem(
        title: 'Настройте условия',
        description:
            'Выберите количество мест, стоимость и комментарии для пассажиров.',
        icon: Icons.tune,
      ),
      HelpGuideItem(
        title: 'Заполните автомобиль',
        description:
            'Марка, цвет и номер машины делают карточку поездки более доверительной.',
        icon: Icons.directions_car,
      ),
      HelpGuideItem(
        title: 'Общайтесь в чате',
        description:
            'Получайте сообщения от пассажиров и быстро уточняйте точку посадки.',
        icon: Icons.forum_outlined,
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(title)),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AppBackdrop(),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accent.withValues(alpha: 0.18),
                        hs.tint,
                        hs.cardBackground,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: hs.stroke),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(heroTitle, style: HSText.title2),
                      const SizedBox(height: 12),
                      Text(
                        heroSubtitle,
                        style: HSText.subheadline.copyWith(
                          color: context.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                for (var i = 0; i < items.length; i++) ...[
                  GlassCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(items[i].icon, size: 18, color: accent),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${i + 1}. ${items[i].title}',
                                style: HSText.headline,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                items[i].description,
                                style: HSText.subheadline.copyWith(
                                  color: context.secondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Ported from `LegalSection` in `ProfileViews.swift`.
class LegalSection {
  const LegalSection({required this.title, required this.body});
  final String title;
  final String body;
}

/// Ported from `LegalDocumentView` in `ProfileViews.swift`.
class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({
    super.key,
    required this.title,
    required this.sections,
  });

  final String title;
  final List<LegalSection> sections;

  static LegalDocumentScreen terms() => const LegalDocumentScreen(
    title: 'Пользовательское соглашение',
    sections: [
      LegalSection(
        title: 'Использование сервиса',
        body:
            'HamSafar помогает пассажирам и водителям находить попутные поездки между городами. Пользователь обязуется указывать достоверные данные и использовать сервис только для реальных поездок.',
      ),
      LegalSection(
        title: 'Ответственность участников',
        body:
            'Водители и пассажиры самостоятельно договариваются о деталях поездки, месте встречи, багаже и оплате. Платформа не заменяет личную ответственность сторон.',
      ),
      LegalSection(
        title: 'Безопасность',
        body:
            'Запрещены мошеннические действия, ложные публикации поездок, спам и оскорбительное поведение в чатах и профиле.',
      ),
    ],
  );

  static LegalDocumentScreen privacy() => const LegalDocumentScreen(
    title: 'Политика конфиденциальности',
    sections: [
      LegalSection(
        title: 'Какие данные используются',
        body:
            'Имя, телефон, email, данные автомобиля и история поездок используются для работы приложения, связи между участниками и поддержки.',
      ),
      LegalSection(
        title: 'Как используются данные',
        body:
            'Контактные данные и маршрутная информация применяются для поиска поездок, отправки сообщений, отображения бронирований и повышения доверия между пользователями.',
      ),
      LegalSection(
        title: 'Защита информации',
        body:
            'Мы не публикуем личные данные вне сервиса и используем их только в рамках функций платформы, поддержки и безопасности.',
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(title)),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AppBackdrop(),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              children: [
                for (var i = 0; i < sections.length; i++) ...[
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${i + 1}. ${sections[i].title}',
                          style: HSText.headline,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          sections[i].body,
                          style: HSText.subheadline.copyWith(
                            color: context.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Ported from `ContactsView` in `ProfileViews.swift`.
class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Контакты')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AppBackdrop(),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              children: [
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Контакты HamSafar', style: HSText.headline),
                      const SizedBox(height: 12),
                      Text(
                        'Выберите удобный канал связи для вопросов по поездкам, '
                        'безопасности и продукту.',
                        style: HSText.subheadline.copyWith(
                          color: context.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                GlassCard(
                  child: Column(
                    children: [
                      _ContactRow(
                        title: 'Общий email',
                        value: 'hello@hamsafar.app',
                        icon: Icons.mail_outline,
                      ),
                      const Divider(),
                      _ContactRow(
                        title: 'Поддержка',
                        value: 'support@hamsafar.app',
                        icon: Icons.support_agent,
                      ),
                      const Divider(),
                      _ContactRow(
                        title: 'Телефон',
                        value: '+998 90 000 00 00',
                        icon: Icons.phone,
                      ),
                      const Divider(),
                      _ContactRow(
                        title: 'Время ответа',
                        value: 'Ежедневно, 09:00 - 22:00',
                        icon: Icons.schedule,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: context.hs.primary),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: HSText.caption.copyWith(color: context.secondaryText),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: HSText.body.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// What kind of contact-intake to send when [FeedbackFormScreen] is submitted.
enum FeedbackKind { support, idea }

/// Ported from `SupportRequestView` / `IdeaSubmissionView` in
/// `ProfileViews.swift` — both are "fill a form, submit to support" screens.
/// Submission is posted to the `contact--intake` Supabase Edge function via
/// `SupabaseService.submitSupportRequest` / `submitIdea`.
class FeedbackFormScreen extends ConsumerStatefulWidget {
  const FeedbackFormScreen({
    super.key,
    required this.appBarTitle,
    required this.cardTitle,
    required this.cardSubtitle,
    required this.fieldHint,
    required this.submitLabel,
    required this.successTitle,
    required this.successMessage,
    required this.kind,
    this.topics,
  });

  final String appBarTitle;
  final String cardTitle;
  final String cardSubtitle;
  final String fieldHint;
  final String submitLabel;
  final String successTitle;
  final String successMessage;
  final FeedbackKind kind;

  /// When provided, a topic picker is shown above the message field.
  final List<String>? topics;

  @override
  ConsumerState<FeedbackFormScreen> createState() => _FeedbackFormScreenState();
}

class _FeedbackFormScreenState extends ConsumerState<FeedbackFormScreen> {
  final _message = TextEditingController();
  late String? _topic = widget.topics?.first;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _message.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Опишите проблему перед отправкой.')),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    final service = ref.read(supabaseServiceProvider);
    final profile = ref.read(currentUserProvider);
    String? errorMessage;
    try {
      if (widget.kind == FeedbackKind.support) {
        await service.submitSupportRequest(
          topic: _topic ?? 'Другое',
          message: text,
          profile: profile,
        );
      } else {
        await service.submitIdea(
          title: text.split('\n').first.trim().isEmpty
              ? 'Идея'
              : text.split('\n').first.trim(),
          details: text,
          profile: profile,
        );
      }
    } catch (e) {
      errorMessage = e.toString();
    }
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Не удалось отправить: $errorMessage'),
      ));
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(widget.successTitle),
        content: Text(widget.successMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Ок'),
          ),
        ],
      ),
    );
    if (mounted) _message.clear();
  }

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(widget.appBarTitle)),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AppBackdrop(),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              children: [
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.cardTitle, style: HSText.headline),
                      const SizedBox(height: 12),
                      Text(
                        widget.cardSubtitle,
                        style: HSText.subheadline.copyWith(
                          color: context.secondaryText,
                        ),
                      ),
                      if (widget.topics != null) ...[
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
                              value: _topic,
                              isExpanded: true,
                              items: [
                                for (final t in widget.topics!)
                                  DropdownMenuItem(value: t, child: Text(t)),
                              ],
                              onChanged: (v) => setState(() => _topic = v),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                GlassCard(
                  child: TextField(
                    controller: _message,
                    minLines: 5,
                    maxLines: 8,
                    decoration: InputDecoration(
                      hintText: widget.fieldHint,
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                PrimaryFilledButton(
                  label: widget.submitLabel,
                  isLoading: _isSubmitting,
                  onPressed: _isSubmitting ? null : _submit,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
