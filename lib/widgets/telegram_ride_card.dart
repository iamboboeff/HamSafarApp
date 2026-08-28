import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/i18n/l10n.dart';
import '../domain/date_formatter.dart';
import '../models/telegram_ride_lead.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'glass_card.dart';

class TelegramRideCard extends StatelessWidget {
  const TelegramRideCard({super.key, required this.lead});

  final TelegramRideLead lead;

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    final actions = _actions();
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: hs.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    lead.sourceChatTitle?.trim().isNotEmpty == true
                        ? lead.sourceChatTitle!.trim()
                        : tr('Из Telegram'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HSText.captionSemibold.copyWith(color: hs.primary),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _relativeTime(lead.sourceSentAt),
                style: HSText.caption.copyWith(color: context.secondaryText),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('${lead.fromCity} → ${lead.toCity}', style: HSText.headline),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _DetailChip(label: _dateLabel()),
              if (lead.seats != null)
                _DetailChip(label: _seatsLabel(lead.seats!)),
              if (lead.price != null) _DetailChip(label: _priceLabel()),
              if (lead.cargo) _DetailChip(label: tr('Берёт посылки')),
              if (!lead.isDriverOffer) _DetailChip(label: tr('Ищут поездку')),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '«${lead.rawText}»',
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: HSText.subheadline.copyWith(
              color: context.secondaryText,
              fontStyle: FontStyle.italic,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.person_outline,
                size: 15,
                color: context.secondaryText,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  lead.displayAuthor,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HSText.captionSemibold.copyWith(
                    color: context.secondaryText,
                  ),
                ),
              ),
              Text(
                tr('Не проверено'),
                style: HSText.caption.copyWith(color: hs.orange),
              ),
            ],
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = (constraints.maxWidth - 8) / 2;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final action in actions)
                      SizedBox(
                        width: width,
                        child: OutlinedButton.icon(
                          onPressed: () => _open(context, action.uri),
                          icon: Icon(action.icon, size: 17),
                          label: Text(action.label),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: context.primaryText,
                            side: BorderSide(color: hs.stroke),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  List<_LeadAction> _actions() {
    final actions = <_LeadAction>[];
    if (lead.telegramUri case final uri?) {
      actions.add(_LeadAction(tr('Написать'), Icons.send_outlined, uri));
    }
    if (lead.whatsappUri case final uri?
        when lead.contactMethods.contains('whatsapp')) {
      actions.add(_LeadAction('WhatsApp', Icons.chat_outlined, uri));
    }
    if (lead.callUri case final uri?
        when lead.contactMethods.contains('phone') ||
            !lead.contactMethods.contains('whatsapp')) {
      actions.add(_LeadAction(tr('Позвонить'), Icons.phone_outlined, uri));
    }
    if (lead.originalUri case final uri?) {
      actions.add(_LeadAction(tr('Оригинал'), Icons.send_outlined, uri));
    }
    return actions;
  }

  Future<void> _open(BuildContext context, Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('Не удалось открыть ссылку.'))));
    }
  }

  String _dateLabel() {
    if (lead.datePrecision == 'fuzzy') return tr('Сегодня или завтра');
    final date = lead.departureDate;
    if (date == null) return tr('Дата не указана');
    final day = DateUtilsX.isToday(date)
        ? tr('Сегодня')
        : DateUtilsX.isTomorrow(date)
        ? tr('Завтра')
        : DateTextFormatter.dayMonthShort(date);
    final time = lead.departureTime;
    return time == null || time.isEmpty ? day : '$day, $time';
  }

  String _priceLabel() {
    final unit = lead.currency == 'UZS' ? tr('сум') : tr('сомони');
    return '${lead.price} $unit';
  }

  static String _seatsLabel(int seats) {
    if (seats == 1) return tr('1 место');
    if ({2, 3, 4}.contains(seats % 10) && !{12, 13, 14}.contains(seats % 100)) {
      return trf('{count} места', {'count': seats});
    }
    return trf('{count} мест', {'count': seats});
  }

  static String _relativeTime(DateTime value) {
    final now = DateTime.now().toUtc().add(const Duration(hours: 5));
    final tripNow = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
      now.second,
    );
    final difference = tripNow.difference(value);
    if (difference.inMinutes < 1) return tr('Только что');
    if (difference.inMinutes < 60) {
      return trf('{count} мин назад', {'count': difference.inMinutes});
    }
    if (difference.inHours < 24) {
      return trf('{count} ч назад', {'count': difference.inHours});
    }
    return DateTextFormatter.dayMonthShort(value);
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: context.hs.tint,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(label, style: HSText.captionSemibold),
  );
}

class _LeadAction {
  const _LeadAction(this.label, this.icon, this.uri);

  final String label;
  final IconData icon;
  final Uri uri;
}
