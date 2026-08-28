import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/telegram_ride_lead.dart';

class TelegramLeadsService {
  const TelegramLeadsService(this._client);

  final SupabaseClient _client;

  Future<List<TelegramRideLead>> fetchActiveLeads() async {
    final rows = await _client
        .from('telegram_ride_leads')
        .select()
        .eq('status', 'active')
        .gt('expires_at', DateTime.now().toUtc().toIso8601String())
        .order('source_sent_at', ascending: false)
        .limit(300);
    return rows.map(TelegramRideLead.fromJson).toList(growable: false);
  }
}
