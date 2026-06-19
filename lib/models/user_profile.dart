import 'dart:convert';
import 'dart:typed_data';

import 'package:hamsafar/core/i18n/l10n.dart';

import '../domain/date_formatter.dart';
import 'residence_country.dart';

/// Ported from `ProfileGender` in `Models.swift`.
enum ProfileGender {
  male,
  female;

  String get title => switch (this) {
    ProfileGender.male => tr('Мужчина'),
    ProfileGender.female => tr('Женщина'),
  };
}

/// Ported from `UserProfile` in `Models.swift`.
class UserProfile {
  const UserProfile({
    required this.id,
    this.backendId,
    required this.name,
    required this.rating,
    required this.completedTrips,
    this.ratingCount = 0,
    this.phoneNumber = '',
    this.email = '',
    this.avatarBytes,
    this.avatarUrl,
    this.gender,
    this.birthDate,
    this.registeredAt,
    this.countryOfResidence,
    this.allowPublicProfile = true,
  });

  final String id;
  final String? backendId;
  final String name;
  final double rating;
  final int completedTrips;

  /// Number of reviews behind [rating]. Zero means the user has no ratings
  /// yet, so [ratingText] shows a placeholder instead of the default 5.0.
  final int ratingCount;
  final String phoneNumber;
  final String email;

  /// Locally-picked avatar bytes, used only as an immediate preview before the
  /// image is uploaded to Storage. Persisted avatars come back via [avatarUrl].
  final Uint8List? avatarBytes;

  /// Public Supabase Storage URL of the avatar (small, CDN-served, cached
  /// between launches). This replaced the old base64 `data:` URLs that were
  /// stored inline in `profiles.avatar_url`.
  final String? avatarUrl;
  final ProfileGender? gender;
  final DateTime? birthDate;
  final DateTime? registeredAt;
  final ResidenceCountry? countryOfResidence;
  final bool allowPublicProfile;

  UserProfile copyWith({
    String? name,
    String? phoneNumber,
    String? email,
    Object? avatarBytes = _unset,
    Object? avatarUrl = _unset,
    ProfileGender? gender,
    DateTime? birthDate,
    ResidenceCountry? countryOfResidence,
    bool? allowPublicProfile,
  }) {
    return UserProfile(
      id: id,
      backendId: backendId,
      name: name ?? this.name,
      rating: rating,
      completedTrips: completedTrips,
      ratingCount: ratingCount,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      avatarBytes: identical(avatarBytes, _unset)
          ? this.avatarBytes
          : avatarBytes as Uint8List?,
      avatarUrl: identical(avatarUrl, _unset)
          ? this.avatarUrl
          : avatarUrl as String?,
      gender: gender ?? this.gender,
      birthDate: birthDate ?? this.birthDate,
      registeredAt: registeredAt,
      countryOfResidence: countryOfResidence ?? this.countryOfResidence,
      allowPublicProfile: allowPublicProfile ?? this.allowPublicProfile,
    );
  }

  static const _unset = Object();

  /// Ported from `ProfileRow.avatarData` — decodes the data URL form
  /// `data:image/...;base64,XXXX` into bytes; returns null if the string is
  /// missing or not a data URL.
  /// Returns the `profiles.avatar_url` value when it's a remote Storage URL
  /// (the current format); null for the legacy inline base64 form.
  static String? avatarUrlFromColumn(String? raw) =>
      (raw != null && raw.startsWith('http')) ? raw : null;

  static Uint8List? decodeAvatarUrl(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final marker = raw.indexOf('base64,');
    if (marker < 0) return null;
    final encoded = raw.substring(marker + 'base64,'.length);
    try {
      return base64Decode(encoded);
    } catch (_) {
      return null;
    }
  }

  /// Ported from `serializedAvatarDataURL` in `SupabaseServiceAccount.swift` —
  /// re-encodes bytes back to a `data:image/jpeg;base64,...` URL ready for the
  /// `profiles.avatar_url` column.
  static String? encodeAvatarBytes(Uint8List? bytes) {
    if (bytes == null || bytes.isEmpty) return null;
    return 'data:image/jpeg;base64,${base64Encode(bytes)}';
  }

  /// First letters of up to two name parts.
  String get initials => name
      .split(' ')
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0])
      .join();

  /// Whether the user has any ratings behind [rating].
  bool get hasRating => ratingCount > 0;

  /// Compact rating for badges — a dash when the user has no reviews yet, so
  /// new users don't appear to have a perfect 5.0 (QA #20).
  String get ratingText => hasRating ? rating.toStringAsFixed(1) : '—';

  /// Russian-pluralised review count, e.g. "1 отзыв" / "3 отзыва" /
  /// "5 отзывов". Based on the real [ratingCount].
  String get reviewsLabel {
    final mod100 = ratingCount % 100;
    final mod10 = ratingCount % 10;
    final String template;
    if (mod100 >= 11 && mod100 <= 14) {
      template = '{n} отзывов';
    } else if (mod10 == 1) {
      template = '{n} отзыв';
    } else if (mod10 >= 2 && mod10 <= 4) {
      template = '{n} отзыва';
    } else {
      template = '{n} отзывов';
    }
    return trf(template, {'n': '$ratingCount'});
  }

  int? get age {
    final birth = birthDate;
    if (birth == null) return null;
    final now = DateTime.now();
    var years = now.year - birth.year;
    if (now.month < birth.month ||
        (now.month == birth.month && now.day < birth.day)) {
      years--;
    }
    return years;
  }

  String _localizedYears(int years) {
    final tens = years % 10;
    final hundreds = years % 100;
    if (tens == 1 && hundreds != 11) return trf('{n} год', {'n': '$years'});
    if (tens >= 2 && tens <= 4 && !(hundreds >= 12 && hundreds <= 14)) {
      return trf('{n} года', {'n': '$years'});
    }
    return trf('{n} лет', {'n': '$years'});
  }

  String get identityLine {
    final genderText = gender?.title ?? tr('Пол не указан');
    final ageValue = age;
    final ageText = ageValue == null
        ? tr('возраст не указан')
        : _localizedYears(ageValue);
    return '$genderText, $ageText';
  }

  String get joinedDateText {
    final registered = registeredAt;
    if (registered == null) return tr('Нет данных');
    return DateTextFormatter.monthYear(registered);
  }
}

/// Ported from `PublicProfileStats` in `SupabaseServiceTypes.swift` — the
/// driver/passenger trip counters returned by the `public_profile_stats` RPC.
class PublicProfileStats {
  const PublicProfileStats({
    required this.driverTripsCount,
    required this.passengerTripsCount,
  });

  final int driverTripsCount;
  final int passengerTripsCount;

  /// Authoritative total used in the profile header so it matches the
  /// per-role breakdown shown in the stats card (QA #21).
  int get totalTrips => driverTripsCount + passengerTripsCount;

  static const empty =
      PublicProfileStats(driverTripsCount: 0, passengerTripsCount: 0);
}
