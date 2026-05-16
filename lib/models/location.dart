import 'residence_country.dart';

/// Ported from `LocationCity` in `Models.swift`.
class LocationCity {
  const LocationCity(this.name);
  final String name;

  @override
  bool operator ==(Object other) => other is LocationCity && other.name == name;

  @override
  int get hashCode => name.hashCode;
}

/// Ported from `LocationCountry` in `Models.swift`.
class LocationCountry {
  const LocationCountry({
    required this.name,
    required this.cities,
    required this.regions,
  });

  final String name;
  final List<LocationCity> cities;
  final List<String> regions;

  /// Mirrors `cityPriorityIndex(for:)` — keeps the well-known cities at the top
  /// of the picker, everything else falls back to directory order.
  int cityPriorityIndex(String cityName) {
    final priority = switch (name) {
      'Таджикистан' => const [
        'Душанбе',
        'Худжанд',
        'Бохтар',
        'Куляб',
        'Турсунзаде',
        'Вахдат',
        'Истаравшан',
        'Пенджикент',
        'Гиссар',
        'Исфара',
        'Канибадам',
        'Хорог',
      ],
      'Узбекистан' => const [
        'Ташкент',
        'Самарканд',
        'Бухара',
        'Андижан',
        'Наманган',
        'Фергана',
        'Нукус',
        'Карши',
        'Ургенч',
        'Термез',
        'Джизак',
        'Навои',
      ],
      _ => const <String>[],
    };
    final index = priority.indexOf(cityName);
    if (index != -1) return index;
    final cityIndex = cities.indexWhere((c) => c.name == cityName);
    return priority.length + (cityIndex == -1 ? 1 << 30 : cityIndex);
  }

  /// Mirrors `regionPriorityIndex(for:)`.
  int regionPriorityIndex(String regionName) {
    final priority = switch (name) {
      'Таджикистан' => const [
        'Хамадони',
        'Дангара',
        'Восе',
        'Фархор',
        'Яван',
        'Шахринав',
        'Рудаки',
        'Айни',
        'Ашт',
        'Матча',
        'Спитамен',
        'Бободжон Гафуров',
      ],
      'Узбекистан' => const [
        'Янгиюль',
        'Чирчик',
        'Ангрен',
        'Бекабад',
        'Кибрай',
        'Паркент',
        'Риштан',
        'Бешарык',
        'Шават',
        'Хазарасп',
      ],
      _ => const <String>[],
    };
    final index = priority.indexOf(regionName);
    if (index != -1) return index;
    final regionIndex = regions.indexOf(regionName);
    return priority.length + (regionIndex == -1 ? 1 << 30 : regionIndex);
  }

  @override
  bool operator ==(Object other) =>
      other is LocationCountry && other.name == name;

  @override
  int get hashCode => name.hashCode;
}

/// Ported from `LocationSelection` in `Models.swift`.
class LocationSelection {
  const LocationSelection({
    required this.country,
    required this.city,
    required this.region,
  });

  final LocationCountry country;
  final LocationCity city;
  final String region;

  String get fullName => city.name == region
      ? '${country.name}, ${city.name}'
      : '${country.name}, ${city.name}, $region';

  LocationSelection copyWith({
    LocationCountry? country,
    LocationCity? city,
    String? region,
  }) {
    return LocationSelection(
      country: country ?? this.country,
      city: city ?? this.city,
      region: region ?? this.region,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LocationSelection &&
      other.country == country &&
      other.city == city &&
      other.region == region;

  @override
  int get hashCode => Object.hash(country, city, region);
}

/// Ported from `LocationDirectory` in `Models.swift`.
abstract final class LocationDirectory {
  static const uzbekistan = LocationCountry(
    name: 'Узбекистан',
    cities: [
      LocationCity('Ташкент'),
      LocationCity('Самарканд'),
      LocationCity('Бухара'),
      LocationCity('Хива'),
      LocationCity('Андижан'),
      LocationCity('Наманган'),
      LocationCity('Фергана'),
      LocationCity('Нукус'),
      LocationCity('Термез'),
      LocationCity('Карши'),
      LocationCity('Джизак'),
      LocationCity('Навои'),
      LocationCity('Гулистан'),
      LocationCity('Ургенч'),
      LocationCity('Коканд'),
      LocationCity('Маргилан'),
      LocationCity('Шахрисабз'),
      LocationCity('Денау'),
      LocationCity('Зарафшан'),
      LocationCity('Кунград'),
    ],
    regions: [
      'Янгиюль',
      'Чирчик',
      'Ангрен',
      'Бекабад',
      'Кибрай',
      'Пскент',
      'Газалкент',
      'Паркент',
      'Риштан',
      'Бешарык',
      'Шават',
      'Хазарасп',
      'Касан',
      'Китаб',
      'Пахтакор',
      'Заамин',
    ],
  );

  static const tajikistan = LocationCountry(
    name: 'Таджикистан',
    cities: [
      LocationCity('Душанбе'),
      LocationCity('Худжанд'),
      LocationCity('Куляб'),
      LocationCity('Бохтар'),
      LocationCity('Истаравшан'),
      LocationCity('Пенджикент'),
      LocationCity('Турсунзаде'),
      LocationCity('Канибадам'),
      LocationCity('Исфара'),
      LocationCity('Хамадони'),
      LocationCity('Нурек'),
      LocationCity('Вахдат'),
      LocationCity('Гиссар'),
      LocationCity('Рогун'),
      LocationCity('Дангара'),
      LocationCity('Фархор'),
      LocationCity('Яван'),
      LocationCity('Хорог'),
      LocationCity('Левакант'),
      LocationCity('Шахринав'),
      LocationCity('Рудаки'),
      LocationCity('Айни'),
      LocationCity('Ашт'),
      LocationCity('Матча'),
      LocationCity('Спитамен'),
      LocationCity('Бободжон Гафуров'),
      LocationCity('Кушониён'),
      LocationCity('Кубодиён'),
      LocationCity('Джайхун'),
      LocationCity('Муминабад'),
      LocationCity('Темурмалик'),
      LocationCity('Восе'),
    ],
    regions: [
      'Хамадони',
      'Дангара',
      'Восе',
      'Фархор',
      'Яван',
      'Шахринав',
      'Рудаки',
      'Айни',
      'Ашт',
      'Матча',
      'Спитамен',
      'Бободжон Гафуров',
      'Кушониён',
      'Кубодиён',
      'Джайхун',
      'Муминабад',
      'Темурмалик',
      'Панч',
      'Балджувон',
      'Варзоб',
    ],
  );

  static const List<LocationCountry> countries = [tajikistan, uzbekistan];

  static LocationSelection cityNamed(String name) {
    for (final country in countries) {
      for (final city in country.cities) {
        if (city.name == name) {
          return LocationSelection(
            country: country,
            city: city,
            region: city.name,
          );
        }
      }
    }
    final fallback = tajikistan.cities.first;
    return LocationSelection(
      country: tajikistan,
      city: fallback,
      region: fallback.name,
    );
  }

  static LocationSelection? find({
    required String countryName,
    required String cityName,
  }) {
    for (final country in countries) {
      if (country.name != countryName) continue;
      for (final city in country.cities) {
        if (city.name == cityName) {
          return LocationSelection(
            country: country,
            city: city,
            region: city.name,
          );
        }
      }
    }
    return null;
  }
}

/// Ported from the `ResidenceCountry` extension that maps a country to its
/// default route endpoints.
extension ResidenceCountryLocations on ResidenceCountry {
  LocationCountry get locationCountry => switch (this) {
    ResidenceCountry.uzbekistan => LocationDirectory.uzbekistan,
    ResidenceCountry.tajikistan => LocationDirectory.tajikistan,
  };

  /// Mirrors `ResidenceCountry.defaultFromLocation` — first directory city.
  LocationSelection get defaultFromLocation {
    final country = locationCountry;
    final city = country.cities.first;
    return LocationSelection(country: country, city: city, region: city.name);
  }

  /// Mirrors `ResidenceCountry.defaultToLocation` — second directory city.
  LocationSelection get defaultToLocation {
    final country = locationCountry;
    final city = country.cities[1];
    return LocationSelection(country: country, city: city, region: city.name);
  }
}
