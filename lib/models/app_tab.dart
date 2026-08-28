import 'package:flutter/material.dart';

/// Ported from `AppTab` in `AppPreferencesDomain.swift`.
///
/// The Swift `systemImage` SF Symbol names are mapped to the closest Material
/// icons here.
enum AppTab {
  home('Главная', Icons.home_outlined, Icons.home),
  trips('Мои поездки', Icons.directions_car_outlined, Icons.directions_car),
  create('Создать', Icons.add_box_outlined, Icons.add_box),
  inbox('Чат', Icons.forum_outlined, Icons.forum),
  profile('Профиль', Icons.person_outline, Icons.person);

  const AppTab(this.title, this.icon, this.selectedIcon);

  final String title;
  final IconData icon;
  final IconData selectedIcon;
}

/// Ported from `HomeListingSection` in `AppPreferencesDomain.swift`.
enum HomeListingSection {
  rides('Поездки'),
  passengers('Пассажиры'),
  telegram('Из Telegram');

  const HomeListingSection(this.title);
  final String title;
}

/// Ported from `TravelMode` in `AppPreferencesDomain.swift`.
enum TravelMode {
  passenger('Пассажир'),
  driver('Водитель');

  const TravelMode(this.title);
  final String title;
}
