import 'package:flutter_test/flutter_test.dart';
import 'package:hamsafar/models/telegram_ride_lead.dart';

void main() {
  test('telegram lead exposes route and contact deep links', () {
    final lead = TelegramRideLead.fromJson({
      'id': 'lead-1',
      'kind': 'offer',
      'from_city': 'Худжанд',
      'to_city': 'Душанбе',
      'departure_date': '2026-08-29',
      'departure_time': '10:30:00',
      'cargo': false,
      'phone': '+992 900 00 11 22',
      'contact_methods': ['telegram', 'whatsapp'],
      'raw_text': 'Худжанд Душанбе',
      'source_sent_at': '2026-08-28T08:00:00Z',
      'created_at': '2026-08-28T08:02:00Z',
      'confidence': 0.94,
      'source_message_ids': [10, 11],
      'source_message_url': 'https://t.me/taxi/10',
      'author_id': 42,
      'author_username': 'driver42',
    });

    expect(lead.matchesRoute('худжанд', 'ДУШАНБЕ'), isTrue);
    expect(lead.departureTime, '10:30');
    expect(lead.telegramUri.toString(), 'https://t.me/driver42');
    expect(lead.whatsappUri.toString(), 'https://wa.me/992900001122');
    expect(lead.callUri.toString(), 'tel:+992900001122');
    expect(lead.originalUri.toString(), 'https://t.me/taxi/10');
    expect(lead.sourceMessageIds, [10, 11]);
  });
}
