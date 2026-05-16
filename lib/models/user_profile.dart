import 'dart:convert';
import 'dart:typed_data';

import '../domain/date_formatter.dart';
import 'residence_country.dart';

/// Ported from `ProfileGender` in `Models.swift`.
enum ProfileGender {
  male,
  female;

  String get title => switch (this) {
    ProfileGender.male => 'Мужчина',
    ProfileGender.female => 'Женщина',
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
    this.phoneNumber = '',
    this.email = '',
    this.avatarBytes,
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
  final String phoneNumber;
  final String email;

  /// Raw avatar bytes, mirroring `UserProfile.avatarData` in Swift. Decoded
  /// from `profiles.avatar_url` when it's stored as a `data:image/...;base64,`
  /// URL and re-encoded back on save.
  final Uint8List? avatarBytes;
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
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      avatarBytes: identical(avatarBytes, _unset)
          ? this.avatarBytes
          : avatarBytes as Uint8List?,
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

  String get ratingText => rating.toStringAsFixed(1);

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
    if (tens == 1 && hundreds != 11) return '$years год';
    if (tens >= 2 && tens <= 4 && !(hundreds >= 12 && hundreds <= 14)) {
      return '$years года';
    }
    return '$years лет';
  }

  String get identityLine {
    final genderText = gender?.title ?? 'Пол не указан';
    final ageValue = age;
    final ageText = ageValue == null
        ? 'возраст не указан'
        : _localizedYears(ageValue);
    return '$genderText, $ageText';
  }

  String get joinedDateText {
    final registered = registeredAt;
    if (registered == null) return 'Нет данных';
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

  static const empty =
      PublicProfileStats(driverTripsCount: 0, passengerTripsCount: 0);
}
