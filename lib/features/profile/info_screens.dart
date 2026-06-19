import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/i18n/l10n.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
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
    required this.heroIcon,
    required this.heroTitle,
    required this.heroSubtitle,
    required this.items,
  });

  final String title;
  final Color accent;
  final IconData heroIcon;
  final String heroTitle;
  final String heroSubtitle;
  final List<HelpGuideItem> items;

  /// The two guides referenced from the Profile screen.
  static HelpGuideScreen passengers(BuildContext context) => HelpGuideScreen(
    title: tr('Пассажирам'),
    accent: context.hs.passenger,
    heroIcon: Icons.airline_seat_recline_extra,
    heroTitle: tr('Как бронировать поездки без лишних шагов'),
    heroSubtitle:
        tr('Поиск, бронирование и общение с водителем в одном месте.'),
    items: [
      HelpGuideItem(
        title: tr('Выберите маршрут'),
        description: tr(
            'Укажите город отправления, назначения и дату, чтобы увидеть подходящие поездки.'),
        icon: Icons.search,
      ),
      HelpGuideItem(
        title: tr('Проверьте водителя'),
        description: tr(
            'Смотрите рейтинг, отзывы, модель машины и количество свободных мест.'),
        icon: Icons.star_outline,
      ),
      HelpGuideItem(
        title: tr('Забронируйте место'),
        description: tr(
            'Подтвердите поездку и сразу переходите в чат для согласования деталей.'),
        icon: Icons.check_circle_outline,
      ),
      HelpGuideItem(
        title: tr('Следите за поездкой'),
        description: tr(
            'Активные бронирования и история всегда доступны в разделе «Мои поездки».'),
        icon: Icons.directions_car_outlined,
      ),
      HelpGuideItem(
        title: tr('Безопасность и доверие'),
        description: tr(
            'Проверяйте профиль и отзывы, согласуйте удобное место встречи. На подозрительного пользователя можно пожаловаться или заблокировать его в профиле и чате.'),
        icon: Icons.shield_outlined,
      ),
    ],
  );

  static HelpGuideScreen drivers(BuildContext context) => HelpGuideScreen(
    title: tr('Водителям'),
    accent: context.hs.primary,
    heroIcon: Icons.directions_car,
    heroTitle: tr('Как быстро опубликовать поездку'),
    heroSubtitle: tr('Маршрут, места, цена и заявки пассажиров под рукой.'),
    items: [
      HelpGuideItem(
        title: tr('Добавьте маршрут'),
        description: tr(
            'Укажите откуда и куда вы едете, затем выберите дату и время отправления.'),
        icon: Icons.alt_route,
      ),
      HelpGuideItem(
        title: tr('Настройте условия'),
        description: tr(
            'Выберите количество мест, стоимость и комментарии для пассажиров.'),
        icon: Icons.tune,
      ),
      HelpGuideItem(
        title: tr('Заполните автомобиль'),
        description: tr(
            'Марка, цвет и номер машины делают карточку поездки более доверительной.'),
        icon: Icons.directions_car,
      ),
      HelpGuideItem(
        title: tr('Общайтесь в чате'),
        description: tr(
            'Получайте сообщения от пассажиров и быстро уточняйте точку посадки.'),
        icon: Icons.forum_outlined,
      ),
      HelpGuideItem(
        title: tr('Будьте на связи и в безопасности'),
        description: tr(
            'Приезжайте вовремя и держите документы под рукой. На пассажира, нарушающего правила, можно пожаловаться или заблокировать его.'),
        icon: Icons.verified_user_outlined,
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
          SingleChildScrollView(
            // Include left/right safe-area insets so content clears the notch /
            // Dynamic Island in landscape (QA #93).
            padding: EdgeInsets.fromLTRB(
              HSSpacing.screen + MediaQuery.paddingOf(context).left,
              HSSpacing.screen,
              HSSpacing.screen + MediaQuery.paddingOf(context).right,
              HSSpacing.screen + 12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHero(context),
                const SizedBox(height: 22),
                for (var i = 0; i < items.length; i++) _buildStep(context, i),
                const SizedBox(height: 8),
                _buildClosing(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Gradient header with an accent icon badge, the step count and the intro.
  Widget _buildHero(BuildContext context) {
    final hs = context.hs;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.withValues(alpha: 0.22), hs.tint, hs.cardBackground],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [accent, accent.withValues(alpha: 0.7)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(heroIcon, color: Colors.white, size: 28),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: hs.cardBackground.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: accent.withValues(alpha: 0.3)),
                ),
                child: Text(
                  _stepsLabel(items.length),
                  style: HSText.captionBold.copyWith(color: accent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(heroTitle, style: HSText.title3),
          const SizedBox(height: 8),
          Text(
            heroSubtitle,
            style: HSText.subheadline
                .copyWith(color: context.secondaryText, height: 1.4),
          ),
        ],
      ),
    );
  }

  /// One step of the guide: a numbered node on a connecting rail plus a card
  /// with the step's icon, title and description.
  Widget _buildStep(BuildContext context, int i) {
    final hs = context.hs;
    final isLast = i == items.length - 1;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [accent, accent.withValues(alpha: 0.72)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.32),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  '${i + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          accent.withValues(alpha: 0.35),
                          accent.withValues(alpha: 0.12),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: hs.cardBackground,
                  borderRadius: BorderRadius.circular(HSRadius.medium),
                  border: Border.all(color: hs.stroke),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child:
                              Icon(items[i].icon, size: 17, color: accent),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child:
                              Text(items[i].title, style: HSText.headline),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      items[i].description,
                      style: HSText.subheadline.copyWith(
                        color: context.secondaryText,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Friendly closing note in the guide's accent colour.
  Widget _buildClosing(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(HSRadius.medium),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, color: accent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tr('Хорошей дороги! Если остались вопросы — напишите нам в поддержку.'),
              style: HSText.subheadline
                  .copyWith(color: context.primaryText, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  /// Russian pluralisation for the step-count chip (1 шаг / 2 шага / 5 шагов).
  String _stepsLabel(int n) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return trf('{n} шаг', {'n': '$n'});
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
      return trf('{n} шага', {'n': '$n'});
    }
    return trf('{n} шагов', {'n': '$n'});
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

  static LegalDocumentScreen terms() => LegalDocumentScreen(
    title: tr('Пользовательское соглашение'),
    sections: [
      LegalSection(
        title: tr('Использование сервиса'),
        body: tr(
            'HamSafar помогает пассажирам и водителям находить попутные поездки между городами. Используя приложение, вы подтверждаете, что вам исполнилось 16 лет, указываете достоверные данные и пользуетесь сервисом только для реальных поездок. Вы отвечаете за сохранность доступа к своему аккаунту.'),
      ),
      LegalSection(
        title: tr('Роль платформы'),
        body: tr(
            'HamSafar — информационный сервис, который связывает водителей и пассажиров для совместных поездок и разделения дорожных расходов. Мы не являемся перевозчиком или службой такси, не организуем поездки и не обрабатываем платежи — об оплате участники договариваются между собой напрямую.'),
      ),
      LegalSection(
        title: tr('Правила публикаций и поведения'),
        body: tr(
            'Действует политика нулевой терпимости к оскорбительному, незаконному и нежелательному контенту и поведению. Запрещены оскорбления, угрозы и домогательства, мошенничество, ложные публикации поездок, спам, разжигание вражды и любые материалы, нарушающие закон или права других людей. Публикуя объявления, сообщения и отзывы, вы соглашаетесь соблюдать эти правила.'),
      ),
      LegalSection(
        title: tr('Жалобы, блокировка и модерация'),
        body: tr(
            'Вы можете пожаловаться на пользователя или контент и заблокировать любого участника в его профиле или в чате. Мы рассматриваем обращения и в течение 24 часов удаляем нарушающий контент и можем ограничить или удалить аккаунт нарушителя. Заблокированные пользователи не видят ваши поездки и сообщения, а вы — их.'),
      ),
      LegalSection(
        title: tr('Ответственность участников'),
        body: tr(
            'Водители и пассажиры самостоятельно договариваются о деталях поездки, месте встречи, багаже и оплате и несут ответственность за свои действия. Соблюдайте осторожность: проверяйте профиль и отзывы, согласуйте удобное и безопасное место посадки.'),
      ),
      LegalSection(
        title: tr('Ограничение ответственности'),
        body: tr(
            'Сервис предоставляется «как есть». HamSafar не несёт ответственности за действия участников, состояние транспорта, исход поездок и договорённости между сторонами. Мы стремимся обеспечивать стабильную работу, но не гарантируем бесперебойность сервиса.'),
      ),
      LegalSection(
        title: tr('Аккаунт, изменения и контакты'),
        body: tr(
            'Вы можете удалить аккаунт и связанные данные в любой момент в разделе «Профиль → Удалить аккаунт». Мы можем обновлять настоящее соглашение; продолжая пользоваться сервисом, вы принимаете изменения. Вопросы: support@hamsafarapp.com.'),
      ),
    ],
  );

  static LegalDocumentScreen privacy() => LegalDocumentScreen(
    title: tr('Политика конфиденциальности'),
    sections: [
      LegalSection(
        title: tr('Какие данные используются'),
        body: tr(
            'Имя, email, телефон, при желании пол, дата рождения, страна и фото профиля; для водителей — данные автомобиля. Также объявления, сообщения в чате, отзывы, история поиска и поездок, идентификатор пользователя и токен устройства для уведомлений. Точную геолокацию устройства и рекламные идентификаторы мы не собираем.'),
      ),
      LegalSection(
        title: tr('Как используются данные'),
        body: tr(
            'Для работы сервиса: поиска и публикации поездок, бронирования, общения в чате, уведомлений, поддержки, а также безопасности и модерации. Другим пользователям видно только то, что вы публикуете (имя, фото, рейтинг, маршруты, сообщения). Номер телефона по умолчанию виден только подтверждённым участникам поездки.'),
      ),
      LegalSection(
        title: tr('Передача и хранение'),
        body: tr(
            'Мы не продаём ваши данные и не передаём их в рекламных целях. Данные хранятся у поставщика инфраструктуры Supabase; push-уведомления доставляются через Firebase Cloud Messaging и Apple Push Notification service. Передача выполняется по защищённому протоколу HTTPS.'),
      ),
      LegalSection(
        title: tr('Ваши права'),
        body: tr(
            'Вы можете редактировать данные профиля, заблокировать пользователя и пожаловаться на него, а также удалить аккаунт и связанные данные в разделе «Профиль → Удалить аккаунт».'),
      ),
      LegalSection(
        title: tr('Контакты'),
        body: tr(
            'Полная версия политики доступна на сайте hamsafarapp.com. По вопросам конфиденциальности: support@hamsafarapp.com.'),
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
          SingleChildScrollView(
            // Include left/right safe-area insets so content clears the notch /
            // Dynamic Island in landscape (QA #93).
            padding: EdgeInsets.fromLTRB(
              20 + MediaQuery.paddingOf(context).left,
              20,
              20 + MediaQuery.paddingOf(context).right,
              20,
            ),
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
      appBar: AppBar(title: Text(tr('Контакты'))),
      body: Stack(
        fit: StackFit.expand,
        children: [
          SingleChildScrollView(
            // Include left/right safe-area insets so content clears the notch /
            // Dynamic Island in landscape (QA #93).
            padding: EdgeInsets.fromLTRB(
              20 + MediaQuery.paddingOf(context).left,
              20,
              20 + MediaQuery.paddingOf(context).right,
              20,
            ),
            child: Column(
              children: [
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('Контакты HamSafar'), style: HSText.headline),
                      const SizedBox(height: 12),
                      Text(
                        tr('Выберите удобный канал связи для вопросов по поездкам, безопасности и продукту.'),
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
                        title: tr('Общий email'),
                        value: 'hello@hamsafarapp.com',
                        icon: Icons.mail_outline,
                        actionUri: Uri.parse('mailto:hello@hamsafarapp.com'),
                      ),
                      const Divider(),
                      _ContactRow(
                        title: tr('Поддержка'),
                        value: 'support@hamsafarapp.com',
                        icon: Icons.support_agent,
                        actionUri: Uri.parse('mailto:support@hamsafarapp.com'),
                      ),
                      const Divider(),
                      _ContactRow(
                        title: tr('Время ответа'),
                        value: tr('Ежедневно, 09:00 - 22:00'),
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
    this.actionUri,
  });

  final String title;
  final String value;
  final IconData icon;

  /// When set, the row is tappable and opens this URI (mailto:/tel:) in the
  /// system handler (QA #98).
  final Uri? actionUri;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: context.hs.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: HSText.caption.copyWith(color: context.secondaryText),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: HSText.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: actionUri != null ? context.hs.primary : null,
                  ),
                ),
              ],
            ),
          ),
          if (actionUri != null)
            Icon(Icons.chevron_right, size: 18, color: context.secondaryText),
        ],
      ),
    );
    if (actionUri == null) return row;
    return InkWell(
      onTap: () => launchUrl(actionUri!, mode: LaunchMode.externalApplication),
      child: row,
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
      // Match the form's purpose — the idea form shouldn't ask to "describe the
      // problem" (QA #95).
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.kind == FeedbackKind.idea
                ? tr('Опишите идею перед отправкой.')
                : tr('Опишите проблему перед отправкой.'),
          ),
        ),
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
        content: Text(trf('Не удалось отправить: {error}', {'error': errorMessage})),
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
            child: Text(tr('Ок')),
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
          SingleChildScrollView(
            // Include left/right safe-area insets so content clears the notch /
            // Dynamic Island in landscape (QA #93).
            padding: EdgeInsets.fromLTRB(
              20 + MediaQuery.paddingOf(context).left,
              20,
              20 + MediaQuery.paddingOf(context).right,
              20,
            ),
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
