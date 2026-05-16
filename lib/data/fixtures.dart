import '../models/booked_trip.dart';
import '../models/passenger_request.dart';
import '../models/residence_country.dart';
import '../models/ride.dart';
import '../models/ride_search.dart';
import '../models/trip_enums.dart';
import '../models/user_profile.dart';

/// In-memory sample data for the Flutter port.
///
/// The SwiftUI app loads rides/requests from Supabase via `SupabaseService`.
/// Until that backend layer is ported, these fixtures let the Home + Search
/// flow run end to end. The shape mirrors `AppStateFixtures.swift`.
abstract final class Fixtures {
  static DateTime _at(int dayOffset, int hour, int minute) {
    final now = DateTime.now();
    final base = DateTime(now.year, now.month, now.day);
    return base.add(Duration(days: dayOffset, hours: hour, minutes: minute));
  }

  static final UserProfile currentUser = UserProfile(
    id: 'user-current',
    backendId: 'AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA',
    name: 'Иброхим Бобоев',
    rating: 4.9,
    completedTrips: 12,
    phoneNumber: '+992900000000',
    email: 'me@hamsafar.app',
    gender: ProfileGender.male,
    countryOfResidence: ResidenceCountry.tajikistan,
    registeredAt: DateTime(2024, 6, 1),
  );

  static final UserProfile _farrukh = UserProfile(
    id: 'user-farrukh',
    backendId: 'BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB',
    name: 'Фаррух Каримов',
    rating: 4.8,
    completedTrips: 64,
    phoneNumber: '+992900000001',
    email: 'farrukh@hamsafar.app',
    gender: ProfileGender.male,
    countryOfResidence: ResidenceCountry.tajikistan,
    registeredAt: DateTime(2023, 2, 14),
  );

  static final UserProfile _sergey = UserProfile(
    id: 'user-sergey',
    backendId: 'CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC',
    name: 'Сергей Иванов',
    rating: 4.6,
    completedTrips: 31,
    phoneNumber: '+998900000002',
    email: 'sergey@hamsafar.app',
    gender: ProfileGender.male,
    countryOfResidence: ResidenceCountry.uzbekistan,
    registeredAt: DateTime(2023, 9, 3),
  );

  static final UserProfile _dilnoza = UserProfile(
    id: 'user-dilnoza',
    backendId: 'DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD',
    name: 'Дилноза Рахимова',
    rating: 5.0,
    completedTrips: 8,
    phoneNumber: '+998900000003',
    email: 'dilnoza@hamsafar.app',
    gender: ProfileGender.female,
    countryOfResidence: ResidenceCountry.uzbekistan,
    registeredAt: DateTime(2024, 1, 20),
  );

  static final UserProfile _akmal = UserProfile(
    id: 'user-akmal',
    backendId: 'EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEEE',
    name: 'Акмал Юсупов',
    rating: 4.7,
    completedTrips: 47,
    phoneNumber: '+992900000004',
    email: 'akmal@hamsafar.app',
    gender: ProfileGender.male,
    countryOfResidence: ResidenceCountry.tajikistan,
    registeredAt: DateTime(2022, 11, 8),
  );

  static Ride _ride({
    required String id,
    required String from,
    required String to,
    required DateTime departure,
    required int price,
    required int seatsLeft,
    required String carModel,
    required UserProfile driver,
    bool instant = false,
    bool maxTwoBack = false,
    String notes = '',
    List<RideReview> reviews = const [],
  }) {
    return Ride(
      id: id,
      backendId: id,
      fromCity: from,
      toCity: to,
      meetingPoint: RidePoint.custom(from, _meetingLabel(from)),
      destinationPoint: RidePoint.custom(to, _destinationLabel(to)),
      departureDate: departure,
      pricePerSeat: price,
      seatsLeft: seatsLeft,
      carModel: carModel,
      routeSummary: '$from - $to',
      notes: Ride.encodedNotes(
        notes,
        instantBookingEnabled: instant,
        maxTwoPassengersInBackEnabled: maxTwoBack,
      ),
      driver: driver,
      reviews: reviews,
      availableSeatLabels: List.generate(seatsLeft, (i) => '${i + 1}'),
    );
  }

  static String _meetingLabel(String city) => switch (city) {
    'Душанбе' => 'Южный автовокзал',
    'Худжанд' => 'Автовокзал Худжанд',
    'Ташкент' => 'Северный вокзал',
    'Самарканд' => 'Регистан, главный вход',
    'Бухара' => 'Ляби-Хауз',
    'Куляб' => 'Центральный рынок',
    _ => 'Центральный вокзал',
  };

  static String _destinationLabel(String city) => switch (city) {
    'Душанбе' => 'Площадь Дусти',
    'Худжанд' => 'Парк Камоли Худжанди',
    'Ташкент' => 'Magic City',
    'Самарканд' => 'Сиабский рынок',
    'Бухара' => 'Старый город',
    'Куляб' => 'Автостанция',
    _ => 'Главная площадь',
  };

  static List<Ride> rides() => [
    currentUserRide,
    _ride(
      id: 'ride-dh-1',
      from: 'Душанбе',
      to: 'Худжанд',
      departure: _at(0, 8, 30),
      price: 180,
      seatsLeft: 3,
      carModel: 'Chevrolet Cobalt',
      driver: _farrukh,
      instant: true,
      maxTwoBack: true,
      notes: 'Выезжаю утром, кондиционер работает.',
      reviews: [
        RideReview(
          id: 'rev-1',
          author: 'Нодира',
          rating: 5,
          comment: 'Очень комфортная поездка, водитель пунктуальный.',
          createdAt: DateTime(2026, 4, 2),
        ),
        RideReview(
          id: 'rev-2',
          author: 'Бахтиёр',
          rating: 4.5,
          comment: 'Всё хорошо, доехали без задержек.',
          createdAt: DateTime(2026, 3, 18),
        ),
      ],
    ),
    _ride(
      id: 'ride-dh-2',
      from: 'Душанбе',
      to: 'Худжанд',
      departure: _at(0, 14, 0),
      price: 160,
      seatsLeft: 2,
      carModel: 'Hyundai Sonata',
      driver: _akmal,
      maxTwoBack: true,
      notes: 'Свободные места сзади.',
    ),
    _ride(
      id: 'ride-dh-3',
      from: 'Душанбе',
      to: 'Худжанд',
      departure: _at(1, 7, 0),
      price: 200,
      seatsLeft: 4,
      carModel: 'Toyota Camry',
      driver: _farrukh,
      instant: true,
      notes: 'Новая машина, едем по новой трассе.',
    ),
    _ride(
      id: 'ride-dh-4',
      from: 'Душанбе',
      to: 'Худжанд',
      departure: _at(2, 9, 30),
      price: 170,
      seatsLeft: 0,
      carModel: 'Chevrolet Malibu',
      driver: _akmal,
    ),
    _ride(
      id: 'ride-hd-1',
      from: 'Худжанд',
      to: 'Душанбе',
      departure: _at(0, 16, 15),
      price: 180,
      seatsLeft: 3,
      carModel: 'Chevrolet Cobalt',
      driver: _akmal,
      instant: true,
    ),
    _ride(
      id: 'ride-hd-2',
      from: 'Худжанд',
      to: 'Душанбе',
      departure: _at(1, 6, 45),
      price: 190,
      seatsLeft: 2,
      carModel: 'Kia K5',
      driver: _farrukh,
      maxTwoBack: true,
    ),
    _ride(
      id: 'ride-ts-1',
      from: 'Ташкент',
      to: 'Самарканд',
      departure: _at(0, 9, 0),
      price: 90,
      seatsLeft: 3,
      carModel: 'Chevrolet Lacetti',
      driver: _sergey,
      instant: true,
      maxTwoBack: true,
    ),
    _ride(
      id: 'ride-ts-2',
      from: 'Ташкент',
      to: 'Самарканд',
      departure: _at(1, 12, 30),
      price: 110,
      seatsLeft: 4,
      carModel: 'Chevrolet Malibu',
      driver: _dilnoza,
      notes: 'Только некурящие, пожалуйста.',
    ),
    _ride(
      id: 'ride-sa-1',
      from: 'Самарканд',
      to: 'Ташкент',
      departure: _at(0, 18, 0),
      price: 95,
      seatsLeft: 2,
      carModel: 'Chevrolet Lacetti',
      driver: _sergey,
    ),
  ];

  static List<PassengerRequest> passengerRequests() => [
    PassengerRequest(
      id: 'req-1',
      backendId: 'req-1',
      passenger: _dilnoza,
      fromCity: 'Душанбе',
      toCity: 'Худжанд',
      departureDate: _at(0, 10, 0),
      seatsNeeded: 1,
      budget: 150,
      note: 'Нужно одно место, еду с небольшой сумкой.',
    ),
    PassengerRequest(
      id: 'req-2',
      backendId: 'req-2',
      passenger: _sergey,
      fromCity: 'Душанбе',
      toCity: 'Худжанд',
      departureDate: _at(1, 8, 0),
      seatsNeeded: 2,
      budget: 320,
      note: 'Едем вдвоём, можем выехать рано утром.',
    ),
    PassengerRequest(
      id: 'req-3',
      backendId: 'req-3',
      passenger: _akmal,
      fromCity: 'Ташкент',
      toCity: 'Самарканд',
      departureDate: _at(0, 13, 0),
      seatsNeeded: 1,
      budget: 100,
      note: '',
    ),
  ];

  static List<LocationSearchHistoryItem> searchHistory() => [
    LocationSearchHistoryItem(
      from: 'Душанбе',
      to: 'Худжанд',
      fromCountry: 'Таджикистан',
      toCountry: 'Таджикистан',
    ),
    LocationSearchHistoryItem(
      from: 'Ташкент',
      to: 'Самарканд',
      fromCountry: 'Узбекистан',
      toCountry: 'Узбекистан',
    ),
  ];

  // --- My Trips -------------------------------------------------------------

  /// A ride published by the current user (the driver-owned trip below wraps
  /// this). Included in [rides] so the marketplace stays consistent with the
  /// publish flow.
  static final Ride currentUserRide = _ride(
    id: 'ride-own-1',
    from: 'Душанбе',
    to: 'Куляб',
    departure: _at(1, 9, 0),
    price: 140,
    seatsLeft: 3,
    carModel: 'Chevrolet Cobalt',
    driver: currentUser,
    instant: true,
    notes: 'Выезжаю утром от Южного автовокзала.',
  );

  static final Ride _completedOwnRide = _ride(
    id: 'ride-own-2',
    from: 'Куляб',
    to: 'Душанбе',
    departure: _at(-4, 7, 30),
    price: 150,
    seatsLeft: 0,
    carModel: 'Chevrolet Cobalt',
    driver: currentUser,
  );

  static List<BookedTrip> bookedTrips() => [
    BookedTrip(
      id: 'trip-driver-active',
      backendId: 'trip-driver-active',
      ride: currentUserRide,
      seatsBooked: 0,
      status: 'Опубликована',
      category: TripCategory.active,
      role: TripRole.driver,
      searchPassengersEnabled: true,
      pendingPassengerCount: 1,
    ),
    BookedTrip(
      id: 'trip-passenger-active',
      backendId: 'trip-passenger-active',
      ride: rides().firstWhere((r) => r.id == 'ride-dh-3'),
      seatsBooked: 1,
      status: 'Ждёт подтверждения',
      category: TripCategory.active,
      role: TripRole.passenger,
    ),
    BookedTrip(
      id: 'trip-driver-history',
      backendId: 'trip-driver-history',
      ride: _completedOwnRide,
      seatsBooked: 0,
      status: 'Завершена',
      category: TripCategory.history,
      role: TripRole.driver,
      confirmedPassengerCount: 2,
    ),
  ];

  static List<PassengerRequest> myPassengerRequests() => [
    PassengerRequest(
      id: 'my-req-1',
      backendId: 'my-req-1',
      passenger: currentUser,
      fromCity: 'Душанбе',
      toCity: 'Бохтар',
      departureDate: _at(2, 11, 0),
      seatsNeeded: 1,
      note: 'Готов выехать в любое время после обеда.',
    ),
  ];
}
