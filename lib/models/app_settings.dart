import 'package:flutter/material.dart';

/// Ported from the preference types in `AppPreferencesDomain.swift`.

/// Ported from `NotificationSettings`.
class NotificationSettings {
  const NotificationSettings({
    this.messages = true,
    this.bookingConfirmations = true,
    this.tripReminders = true,
    this.promotions = false,
  });

  final bool messages;
  final bool bookingConfirmations;
  final bool tripReminders;
  final bool promotions;

  NotificationSettings copyWith({
    bool? messages,
    bool? bookingConfirmations,
    bool? tripReminders,
    bool? promotions,
  }) {
    return NotificationSettings(
      messages: messages ?? this.messages,
      bookingConfirmations: bookingConfirmations ?? this.bookingConfirmations,
      tripReminders: tripReminders ?? this.tripReminders,
      promotions: promotions ?? this.promotions,
    );
  }
}

/// Ported from `AppLanguage`.
enum AppLanguage {
  russian('Русский'),
  english('English');

  const AppLanguage(this.title);
  final String title;
}

/// Ported from `AppThemePreference`.
enum AppThemePreference {
  system('Авто'),
  light('Светлая'),
  dark('Тёмная');

  const AppThemePreference(this.title);
  final String title;

  ThemeMode get themeMode => switch (this) {
    AppThemePreference.system => ThemeMode.system,
    AppThemePreference.light => ThemeMode.light,
    AppThemePreference.dark => ThemeMode.dark,
  };
}

/// Ported from `AppearanceSettings`.
class AppearanceSettings {
  const AppearanceSettings({
    this.language = AppLanguage.russian,
    this.theme = AppThemePreference.system,
  });

  final AppLanguage language;
  final AppThemePreference theme;

  AppearanceSettings copyWith({
    AppLanguage? language,
    AppThemePreference? theme,
  }) {
    return AppearanceSettings(
      language: language ?? this.language,
      theme: theme ?? this.theme,
    );
  }
}

/// Ported from `PrivacySettings`.
class PrivacySettings {
  const PrivacySettings({this.allowPublicProfile = true});

  final bool allowPublicProfile;

  PrivacySettings copyWith({bool? allowPublicProfile}) {
    return PrivacySettings(
      allowPublicProfile: allowPublicProfile ?? this.allowPublicProfile,
    );
  }
}
