import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/app_settings.dart';

/// Ported from `reviewPromptDismissalCount` / `recordReviewPromptDismissal`
/// helpers in `ContentCoordinatorTripLifecycle.swift`. Counts how many times
/// the user has dismissed the leave-review banner for a given prompt id, so
/// the banner can be suppressed (count >= 2), shown immediately (count == 0),
/// or shown after a 6h cool-down (count == 1).
class ReviewPromptDismissalStore {
  ReviewPromptDismissalStore._();

  static String _key(String promptId) =>
      'hamsafar.reviewPrompt.dismissals.$promptId';

  static Future<int> dismissalCount(String promptId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_key(promptId)) ?? 0;
  }

  static Future<void> recordDismissal(String promptId) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_key(promptId)) ?? 0;
    await prefs.setInt(_key(promptId), current + 1);
  }

  /// Marks the prompt as fully resolved (matches Swift's `set(2, ...)` after
  /// a successful review submission).
  static Future<void> markSubmitted(String promptId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key(promptId), 2);
  }
}

/// Ported from `AppPreferencesStore` in `AppPreferencesDomain.swift`. Persists
/// the user-facing preference bundle (notifications, appearance, privacy) to
/// `SharedPreferences`, keyed by the signed-in user's backend id.
class AppPreferencesStore {
  AppPreferencesStore._();

  static String _key(String? backendId) =>
      backendId == null ? 'hamsafar.appPreferences.guest'
                        : 'hamsafar.appPreferences.$backendId';

  static Future<void> save({
    required String? backendId,
    required NotificationSettings notifications,
    required AppearanceSettings appearance,
    required PrivacySettings privacy,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode({
      'notifications': {
        'messages': notifications.messages,
        'bookingConfirmations': notifications.bookingConfirmations,
        'tripReminders': notifications.tripReminders,
        'promotions': notifications.promotions,
      },
      'appearance': {
        'language': appearance.language.name,
        'theme': appearance.theme.name,
      },
      'privacy': {
        'allowPublicProfile': privacy.allowPublicProfile,
      },
    });
    await prefs.setString(_key(backendId), payload);
  }

  static Future<CachedAppPreferences?> load({required String? backendId}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(backendId));
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final n = (json['notifications'] as Map?)?.cast<String, dynamic>() ?? {};
      final a = (json['appearance'] as Map?)?.cast<String, dynamic>() ?? {};
      final p = (json['privacy'] as Map?)?.cast<String, dynamic>() ?? {};
      return CachedAppPreferences(
        notifications: NotificationSettings(
          messages: n['messages'] as bool? ?? true,
          bookingConfirmations: n['bookingConfirmations'] as bool? ?? true,
          tripReminders: n['tripReminders'] as bool? ?? true,
          promotions: n['promotions'] as bool? ?? false,
        ),
        appearance: AppearanceSettings(
          language: AppLanguage.values.firstWhere(
            (e) => e.name == a['language'],
            orElse: () => AppLanguage.russian,
          ),
          theme: AppThemePreference.values.firstWhere(
            (e) => e.name == a['theme'],
            orElse: () => AppThemePreference.system,
          ),
        ),
        privacy: PrivacySettings(
          allowPublicProfile: p['allowPublicProfile'] as bool? ?? true,
        ),
      );
    } catch (_) {
      return null;
    }
  }
}

class CachedAppPreferences {
  const CachedAppPreferences({
    required this.notifications,
    required this.appearance,
    required this.privacy,
  });

  final NotificationSettings notifications;
  final AppearanceSettings appearance;
  final PrivacySettings privacy;
}
