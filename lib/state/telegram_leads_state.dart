import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/telegram_leads_service.dart';
import '../models/telegram_ride_lead.dart';

final telegramLeadsServiceProvider = Provider<TelegramLeadsService>(
  (_) => TelegramLeadsService(Supabase.instance.client),
);

class TelegramLeadsState {
  const TelegramLeadsState({
    required this.items,
    this.isLoading = false,
    this.hasLoadFailed = false,
  });

  final List<TelegramRideLead> items;
  final bool isLoading;
  final bool hasLoadFailed;

  static const initial = TelegramLeadsState(items: [], isLoading: true);

  TelegramLeadsState copyWith({
    List<TelegramRideLead>? items,
    bool? isLoading,
    bool? hasLoadFailed,
  }) => TelegramLeadsState(
    items: items ?? this.items,
    isLoading: isLoading ?? this.isLoading,
    hasLoadFailed: hasLoadFailed ?? this.hasLoadFailed,
  );
}

class TelegramLeadsNotifier extends Notifier<TelegramLeadsState> {
  @override
  TelegramLeadsState build() {
    Future.microtask(refresh);
    return TelegramLeadsState.initial;
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, hasLoadFailed: false);
    try {
      final items = await ref
          .read(telegramLeadsServiceProvider)
          .fetchActiveLeads();
      state = TelegramLeadsState(items: items);
    } catch (error, stackTrace) {
      debugPrint('fetchTelegramRideLeads failed: $error\n$stackTrace');
      state = state.copyWith(isLoading: false, hasLoadFailed: true);
    }
  }
}

final telegramLeadsProvider =
    NotifierProvider<TelegramLeadsNotifier, TelegramLeadsState>(
      TelegramLeadsNotifier.new,
    );
