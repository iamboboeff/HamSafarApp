import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hamsafar/core/i18n/l10n.dart';
import '../../core/supabase/supabase_service.dart';
import '../../domain/create_ride_flow.dart';
import '../../domain/create_ride_presentation.dart';
import '../../domain/date_formatter.dart';
import '../../models/app_tab.dart';
import '../../models/create_flow.dart';
import '../../models/create_ride_draft.dart';
import '../../models/residence_country.dart';
import '../../models/ride.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/app_backdrop.dart';
import '../../widgets/buttons.dart';
import '../../widgets/hs_route.dart';
import '../../widgets/month_calendar.dart';
import '../auth/auth_screen.dart';
import '../home/widgets/date_picker_sheet.dart';
import '../home/widgets/location_picker_sheet.dart';
import 'widgets/create_cards.dart';
import 'widgets/role_selection.dart';
import 'widgets/wizard_components.dart';

/// Ported from `CreateRideView` in `CreateRideViews.swift`.
///
/// Role selection -> either the 8-step driver wizard or the single-page
/// passenger request form. Publishing goes through the real Supabase backend
/// via [SupabaseService].
class CreateRideScreen extends ConsumerStatefulWidget {
  const CreateRideScreen({super.key});

  @override
  ConsumerState<CreateRideScreen> createState() => _CreateRideScreenState();
}

class _CreateRideScreenState extends ConsumerState<CreateRideScreen> {
  CreateFlowState _flow = const CreateFlowState.roleSelection();
  CreateRideDraft _draft = CreateRideDraft();
  bool _isPublishing = false;
  bool _didApplyDefaults = false;

  /// Currency the driver is pricing this ride in. Defaults to their residence
  /// country's currency but can be switched (TJS/UZS) in the price step (QA #99).
  ResidenceCountry? _pricingCurrencyOverride;

  final _priceController = TextEditingController();
  final _notesController = TextEditingController();
  final _customDepartureController = TextEditingController();
  final _customArrivalController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Let the shell route Android system-back into the wizard (QA #69).
    // Registered post-frame so we don't mutate a provider during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(inTabBackHandlerProvider.notifier).set(_handleSystemBack);
      }
    });
  }

  /// Steps back through the wizard when it's open; returns false on the role
  /// selection screen so the shell can fall back to Home / app exit.
  bool _handleSystemBack() {
    if (_flow.phase != CreateFlowPhase.roleSelection) {
      _back();
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    ref.read(inTabBackHandlerProvider.notifier).set(null);
    _priceController.dispose();
    _notesController.dispose();
    _customDepartureController.dispose();
    _customArrivalController.dispose();
    super.dispose();
  }

  /// TJS is the default pricing currency (and the first option) regardless of
  /// the driver's residence country.
  ResidenceCountry get _currency =>
      _pricingCurrencyOverride ?? ResidenceCountry.tajikistan;

  /// Currencies in display order: TJS first, UZS second.
  static const _currencyOptions = [
    ResidenceCountry.tajikistan,
    ResidenceCountry.uzbekistan,
  ];

  /// Max price per currency: 1000 for TJS, 1_000_000 for UZS.
  int _maxPriceFor(ResidenceCountry currency) =>
      currency == ResidenceCountry.uzbekistan ? 1000000 : 1000;

  int get _priceMax => _maxPriceFor(_currency);

  int get _priceValue =>
      CreateRideFlow.sanitizedAmount(_priceController.text, max: _priceMax);

  int get _driverSeatLimit => CreateRidePresentation.driverSeatLimit(
    ref.read(carProfileProvider),
    maxTwoPassengersInBack: _draft.maxTwoPassengersInBack,
  );

  DateTime get _mergedDepartureDate =>
      CreateRidePresentation.mergedDepartureDate(
        departureDate: _draft.departureDate,
        departureTime: _draft.departureTime,
      );

  RidePoint get _departurePoint => CreateRidePresentation.departurePoint(
    selection: _draft.selectedDepartureMeetingPoint,
    customText: _draft.customDepartureMeetingText,
    isCustomSelected: _draft.isCustomDepartureMeetingSelected,
    cityName: _draft.departureLocation.city.name,
  );

  RidePoint get _arrivalPoint => CreateRidePresentation.arrivalPoint(
    selection: _draft.selectedArrivalMeetingPoint,
    customText: _draft.customArrivalMeetingText,
    isCustomSelected: _draft.isCustomArrivalMeetingSelected,
    cityName: _draft.destinationLocation.city.name,
  );

  void _ensureDefaults() {
    if (_didApplyDefaults) return;
    _didApplyDefaults = true;
    _draft.applyPreferredCountryDefaultsIfNeeded(
      ref.read(residenceCountryProvider),
    );
    _syncDriverSeats();
  }

  void _syncDriverSeats() {
    final synced = CreateRidePresentation.syncDriverSeatSelection(
      seats: _draft.seats,
      carProfile: ref.read(carProfileProvider),
      maxTwoPassengersInBack: _draft.maxTwoPassengersInBack,
    );
    _draft.seats = synced.seats;
    _draft.availableSeatLabels = synced.labels;
  }

  void _selectRole(TravelMode mode) {
    // Guests may browse the role picker, but committing to "Я водитель" /
    // "Я пассажир" requires an account — open the auth sheet instead of
    // entering the wizard (QA #16, BlaBlaCar-style soft gate).
    if (!ref.read(isAuthenticatedProvider)) {
      Navigator.of(context).push(
        HSRoute<void>(
          builder: (_) => const AuthScreen(),
          fullscreenDialog: true,
        ),
      );
      return;
    }
    setState(() {
      if (mode == TravelMode.driver) {
        // Apply the role's seat default only on a fresh start. When resuming a
        // half-filled draft (e.g. coming back to the start via "+") keep the
        // user's entries instead of wiping them.
        if (!_draft.hasSelectedDriverFrom && !_draft.hasSelectedDriverTo) {
          _draft.seats = _driverSeatLimit;
          _syncDriverSeats();
        }
        _flow = const CreateFlowState(CreateFlowPhase.driver);
      } else {
        if (!_draft.hasSelectedPassengerFrom && !_draft.hasSelectedPassengerTo) {
          _draft.seats = 1;
        }
        _flow = const CreateFlowState(CreateFlowPhase.passenger);
      }
    });
  }

  void _advance() => setState(() => _flow = CreateRideFlow.advance(_flow));

  void _back() {
    setState(() => _flow = CreateRideFlow.back(_flow.step, _flow.mode!));
  }

  Future<void> _pickLocation({
    required bool isFrom,
    required bool isDriver,
  }) async {
    final result = await showLocationPicker(
      context,
      title: isFrom ? tr('Откуда') : tr('Куда'),
      availableCountries: ref.read(availableTravelCountriesProvider),
    );
    if (result == null) return;
    setState(() {
      if (isFrom) {
        _draft.departureLocation = result;
        _draft.selectedDepartureMeetingPoint = null;
        _draft.customDepartureMeetingText = '';
        _draft.isCustomDepartureMeetingSelected = false;
        _customDepartureController.clear();
        if (isDriver) {
          _draft.hasSelectedDriverFrom = true;
        } else {
          _draft.hasSelectedPassengerFrom = true;
        }
      } else {
        _draft.destinationLocation = result;
        _draft.selectedArrivalMeetingPoint = null;
        _draft.customArrivalMeetingText = '';
        _draft.isCustomArrivalMeetingSelected = false;
        _customArrivalController.clear();
        if (isDriver) {
          _draft.hasSelectedDriverTo = true;
        } else {
          _draft.hasSelectedPassengerTo = true;
        }
      }
    });
  }

  Future<void> _pickDate() async {
    final result = await showDatePickerSheet(
      context,
      initialDate: _draft.departureDate,
    );
    if (result != null) setState(() => _draft.departureDate = result);
  }

  Future<void> _publish() async {
    if (_isPublishing) return;
    final mode = _flow.mode!;

    // Client-side guards (the server also validates cooldown/duplicates/limits).
    // First pass: against the local clock so we can fail fast without a roundtrip.
    if (_mergedDepartureDate.isBefore(DateTime.now())) {
      _showError(tr('Нельзя создать поездку на прошедшие дату или время.'));
      return;
    }
    // Origin and destination must differ (QA #76).
    if (_draft.departureLocation.city.name.trim().toLowerCase() ==
        _draft.destinationLocation.city.name.trim().toLowerCase()) {
      _showError(tr('Пункты отправления и назначения должны отличаться.'));
      return;
    }
    if (mode == TravelMode.driver && _priceValue < 1) {
      _showError(
        trf('Сумма должна быть от 1 до {max}.', {
          'max': _currency.formatAmount(_priceMax),
        }),
      );
      return;
    }
    // A driver can't publish a ride until their vehicle is set up — otherwise
    // passengers see a ride with no car details.
    if (mode == TravelMode.driver &&
        !ref.read(carProfileProvider).isComplete) {
      _showError(
        tr('Заполните данные автомобиля в профиле, чтобы опубликовать поездку.'),
      );
      return;
    }
    // Only adults may drive — block publishing for underage drivers (#79).
    if (mode == TravelMode.driver) {
      final age = ref.read(currentUserProvider).age;
      if (age != null && age < 18) {
        _showError(
          tr('Создавать поездки могут только пользователи старше 18 лет.'),
        );
        return;
      }
    }

    setState(() => _isPublishing = true);
    final service = ref.read(supabaseServiceProvider);

    // Second pass: re-validate against server time so a skewed device clock
    // can't sneak through a "future" departure that is actually in the past
    // server-side. Mirrors `CreateRideViews.swift:1079`. We fall back to the
    // local check if the server is unreachable so transient network blips
    // don't block a legitimate publish.
    try {
      final serverNow = await service.fetchCurrentServerDate();
      if (_mergedDepartureDate.toUtc().isBefore(serverNow)) {
        setState(() => _isPublishing = false);
        _showError(tr('Нельзя создать поездку на прошедшие дату или время.'));
        return;
      }
    } catch (_) {
      // Ignore — local-clock guard above already ran.
    }
    final from = _draft.departureLocation;
    final to = _draft.destinationLocation;
    try {
      if (mode == TravelMode.driver) {
        final ride = await service.publishRide(
          payload: RidePublishPayload(
            fromCountry: from.country.name,
            fromCity: from.city.name,
            fromAddress: _departurePoint.addressLine,
            toCountry: to.country.name,
            toCity: to.city.name,
            toAddress: _arrivalPoint.addressLine,
            departureAt: _mergedDepartureDate,
            pricePerSeat: _priceValue,
            seatsTotal: _draft.availableSeatLabels.length,
            availableSeatLabels: _draft.availableSeatLabels,
            notes: Ride.encodedNotes(
              _notesController.text,
              instantBookingEnabled: _draft.instantBookingEnabled,
              maxTwoPassengersInBackEnabled: _draft.maxTwoPassengersInBack,
            ),
            routeSummary:
                'Маршрут между ${from.city.name} и ${to.city.name}',
            currency: _currency.currencyCode,
          ),
          driver: ref.read(currentUserProvider),
          carProfile: ref.read(carProfileProvider),
        );
        ref.read(marketplaceProvider.notifier).addRide(ride);
        ref.read(bookedTripsProvider.notifier).refresh();
      } else {
        final request = await service.publishPassengerRequest(
          payload: PassengerRequestPublishPayload(
            fromCountry: from.country.name,
            fromCity: from.city.name,
            toCountry: to.country.name,
            toCity: to.city.name,
            departureAt: _mergedDepartureDate,
            seatsNeeded: _draft.seats,
            budget: 0,
            note: _notesController.text,
          ),
          passenger: ref.read(currentUserProvider),
        );
        ref.read(marketplaceProvider.notifier).addPassengerRequest(request);
        ref.read(myPassengerRequestsProvider.notifier).add(request);
        ref
            .read(selectedHomeSectionProvider.notifier)
            .select(HomeListingSection.passengers);
      }
    } on SupabaseServiceError catch (e) {
      if (mounted) {
        setState(() => _isPublishing = false);
        _showError(e.message);
      }
      return;
    } catch (e) {
      if (mounted) {
        setState(() => _isPublishing = false);
        _showError(tr('Не удалось опубликовать. Попробуйте ещё раз.'));
      }
      return;
    }

    if (!mounted) return;
    setState(() => _isPublishing = false);

    // First contextually-relevant moment for push: the publisher will want to
    // hear when someone books / a driver responds. Prompts once; later no-op.
    ref.read(sessionProvider.notifier).ensurePushPermission();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('Поездка опубликована')),
        content: Text(
          mode == TravelMode.driver
              ? tr('Ваша поездка теперь доступна пассажирам.')
              : tr('Ваш запрос опубликован. Водители смогут связаться с вами.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(tr('Закрыть')),
          ),
        ],
      ),
    );

    if (!mounted) return;
    _resetFlow();
    ref
        .read(selectedTabProvider.notifier)
        .select(mode == TravelMode.driver ? AppTab.trips : AppTab.home);
  }

  /// Returns to the role-selection start WITHOUT clearing anything, so tapping
  /// "+" on a half-filled form keeps every entry (cities, date, price, notes).
  void _goToStart() {
    if (_flow.phase == CreateFlowPhase.roleSelection) return;
    setState(() => _flow = const CreateFlowState.roleSelection());
  }

  /// Full reset to a blank draft — used after a successful publish so the next
  /// ride/request starts clean.
  void _resetFlow() {
    setState(() {
      _flow = const CreateFlowState.roleSelection();
      _draft = CreateRideDraft();
      _didApplyDefaults = false;
      _pricingCurrencyOverride = null;
      _priceController.clear();
      _notesController.clear();
      _customDepartureController.clear();
      _customArrivalController.clear();
    });
  }

  void _showError(String message) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('Не удалось опубликовать')),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(tr('Ок')),
          ),
        ],
      ),
    );
  }

  /// A gentle inline prompt (not a publish-error dialog) for missing-field
  /// nudges like "выберите город" — keeps required-step guidance friendly.
  void _showHint(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    _ensureDefaults();
    // Tapping the "+" tab jumps back to the role-selection start but keeps the
    // half-filled draft intact (the user can resume where they left off).
    ref.listen(createTabResetProvider, (_, _) {
      if (mounted) _goToStart();
    });
    return BackdropScaffoldBody(
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: switch (_flow.phase) {
            CreateFlowPhase.roleSelection => RoleSelectionView(
              onSelectRole: _selectRole,
            ),
            CreateFlowPhase.driver => _buildDriverWizard(),
            CreateFlowPhase.passenger => _buildPassengerForm(),
          },
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Driver wizard
  // --------------------------------------------------------------------------

  Widget _buildDriverWizard() {
    final step = _flow.step;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WizardHeader(
            title: tr(step.title(TravelMode.driver)),
            subtitle: tr(step.subtitle(TravelMode.driver)),
            progress: step.progress,
            onBack: _back,
          ),
          const SizedBox(height: 18),
          switch (step) {
            CreateWizardStep.from => _driverFromStep(),
            CreateWizardStep.to => _driverToStep(),
            CreateWizardStep.date => _dateStep(),
            CreateWizardStep.time => _timeStep(TravelMode.driver),
            CreateWizardStep.seats => _seatsStep(TravelMode.driver),
            CreateWizardStep.price => _priceStep(),
            CreateWizardStep.notes => _notesStep(TravelMode.driver),
            CreateWizardStep.summary => _summaryStep(TravelMode.driver),
          },
        ],
      ),
    );
  }

  Widget _driverFromStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WizardFieldRow(
          icon: Icons.trip_origin,
          iconColor: context.hs.primary,
          value: _draft.hasSelectedDriverFrom
              ? _draft.departureLocation.city.name
              : null,
          placeholder: tr('Откуда'),
          onTap: () => _pickLocation(isFrom: true, isDriver: true),
        ),
        const SizedBox(height: 16),
        MeetingPlaceSelectorCard(
          title: tr('Место встречи'),
          subtitle: tr('Необязательно'),
          places: CreateRidePresentation.meetingOptions(
            _draft.departureLocation.city.name,
            RidePointKind.meeting,
          ),
          selectedPlace: _draft.selectedDepartureMeetingPoint,
          customText: _draft.customDepartureMeetingText,
          isCustomSelected: _draft.isCustomDepartureMeetingSelected,
          customController: _customDepartureController,
          onChoose: (place, custom) => setState(() {
            _draft.selectedDepartureMeetingPoint = place;
            _draft.isCustomDepartureMeetingSelected = custom;
            if (place != null) _draft.isCustomDepartureMeetingSelected = false;
            if (!custom) {
              _draft.customDepartureMeetingText = '';
              _customDepartureController.clear();
            }
          }),
          onCustomTextChanged: (value) =>
              _draft.customDepartureMeetingText = value,
        ),
        const SizedBox(height: 16),
        // "Откуда" is required — block advancing and tell the user why instead
        // of a silently-disabled button (QA #13).
        PrimaryFilledButton(
          label: tr('Продолжить'),
          onPressed: () {
            if (!_draft.hasSelectedDriverFrom) {
              _showHint(tr('Сначала выберите город отправления.'));
              return;
            }
            _advance();
          },
        ),
      ],
    );
  }

  Widget _driverToStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WizardFieldRow(
          icon: Icons.location_on,
          iconColor: context.hs.orange,
          value: _draft.hasSelectedDriverTo
              ? _draft.destinationLocation.city.name
              : null,
          placeholder: tr('Куда'),
          onTap: () => _pickLocation(isFrom: false, isDriver: true),
        ),
        const SizedBox(height: 16),
        MeetingPlaceSelectorCard(
          title: tr('Место прибытия'),
          subtitle: tr('Необязательно'),
          places: CreateRidePresentation.meetingOptions(
            _draft.destinationLocation.city.name,
            RidePointKind.destination,
          ),
          selectedPlace: _draft.selectedArrivalMeetingPoint,
          customText: _draft.customArrivalMeetingText,
          isCustomSelected: _draft.isCustomArrivalMeetingSelected,
          customController: _customArrivalController,
          onChoose: (place, custom) => setState(() {
            _draft.selectedArrivalMeetingPoint = place;
            _draft.isCustomArrivalMeetingSelected = custom;
            if (place != null) _draft.isCustomArrivalMeetingSelected = false;
            if (!custom) {
              _draft.customArrivalMeetingText = '';
              _customArrivalController.clear();
            }
          }),
          onCustomTextChanged: (value) =>
              _draft.customArrivalMeetingText = value,
        ),
        const SizedBox(height: 16),
        // "Куда" is required — block advancing and tell the user why (QA #13).
        PrimaryFilledButton(
          label: tr('Продолжить'),
          onPressed: () {
            if (!_draft.hasSelectedDriverTo) {
              _showHint(tr('Сначала выберите город назначения.'));
              return;
            }
            _advance();
          },
        ),
      ],
    );
  }

  Widget _dateStep() {
    return MonthCalendar(
      selectedDate: _draft.departureDate,
      earliestDate: DateUtilsX.startOfDay(DateTime.now()),
      scrollHeight: 520,
      onSelect: (date) {
        setState(() => _draft.departureDate = date);
        Future.delayed(const Duration(milliseconds: 120), () {
          if (mounted) _advance();
        });
      },
    );
  }

  Widget _timeStep(TravelMode mode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SearchInfoTile(
          title: tr('Дата поездки'),
          value: DateTextFormatter.dayMonthYear(_draft.departureDate),
          icon: Icons.calendar_today,
          onTap: _pickDate,
        ),
        const SizedBox(height: 18),
        Text(
          mode == TravelMode.driver
              ? tr('Во сколько заберёте пассажиров?')
              : tr('Во сколько хотите выехать?'),
          style: HSText.headline,
        ),
        const SizedBox(height: 8),
        Text(
          mode == TravelMode.driver
              ? tr('Пассажиры увидят точное время отправления.')
              : tr('Выберите удобное время, чтобы водителям было проще откликнуться.'),
          style: HSText.subheadline.copyWith(color: context.secondaryText),
        ),
        const SizedBox(height: 18),
        CreateTimeSelectionCard(
          title: mode == TravelMode.driver
              ? tr('Время выезда')
              : tr('Удобное время'),
          time: _draft.departureTime,
          onChanged: (value) => setState(() => _draft.departureTime = value),
        ),
        const SizedBox(height: 16),
        PrimaryFilledButton(label: tr('Продолжить'), onPressed: _advance),
      ],
    );
  }

  Widget _seatsStep(TravelMode mode) {
    final isDriver = mode == TravelMode.driver;
    final limit = isDriver ? _driverSeatLimit : 4;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isDriver
              ? tr('Сколько попутчиков возьмёте в дорогу?')
              : tr('Сколько мест вам нужно?'),
          style: HSText.headline,
        ),
        const SizedBox(height: 8),
        CreateCounterSelector(
          value: _draft.seats.clamp(1, limit),
          min: 1,
          max: limit,
          onChanged: (value) => setState(() {
            _draft.seats = value;
            if (isDriver) _syncDriverSeats();
          }),
        ),
        if (isDriver) ...[
          Text(
            trf('Свободных мест: {count}', {'count': _draft.seats}),
            style: HSText.subheadline.copyWith(color: context.secondaryText),
          ),
          const SizedBox(height: 16),
          CreateCheckboxOptionCard(
            title: tr('Максимум двое сзади'),
            subtitle: tr('Пустое сиденье посередине делает поездку комфортнее.'),
            isSelected: _draft.maxTwoPassengersInBack,
            trailingIcon: Icons.people_outline,
            onTap: () => setState(() {
              _draft.maxTwoPassengersInBack = !_draft.maxTwoPassengersInBack;
              if (_draft.seats > _driverSeatLimit) {
                _draft.seats = _driverSeatLimit;
              }
              _syncDriverSeats();
            }),
          ),
          const SizedBox(height: 8),
          CreateCheckboxOptionCard(
            title: tr('Мгновенная бронь'),
            subtitle: tr('Пассажиры бронируют сразу, без ожидания подтверждения.'),
            isSelected: _draft.instantBookingEnabled,
            trailingIcon: Icons.bolt,
            onTap: () => setState(() {
              _draft.instantBookingEnabled = !_draft.instantBookingEnabled;
            }),
          ),
        ],
        const SizedBox(height: 16),
        PrimaryFilledButton(label: tr('Продолжить'), onPressed: _advance),
      ],
    );
  }

  Widget _priceStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr('Укажите цену за одно место'), style: HSText.headline),
        const SizedBox(height: 8),
        Text(
          tr('Пассажиры увидят стоимость за одного человека.'),
          style: HSText.subheadline.copyWith(color: context.secondaryText),
        ),
        const SizedBox(height: 16),
        Text(
          tr('Валюта'),
          style: HSText.captionSemibold.copyWith(color: context.secondaryText),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final currency in _currencyOptions) ...[
              _CurrencyChip(
                label: currency.currencyCode,
                isSelected: _currency == currency,
                onTap: () => setState(() {
                  _pricingCurrencyOverride = currency;
                  // Re-clamp any already-typed price to the new currency's max.
                  final v = CreateRideFlow.sanitizedAmount(
                    _priceController.text,
                    max: _maxPriceFor(currency),
                  );
                  _priceController.text = v == 0 ? '' : '$v';
                }),
              ),
              const SizedBox(width: 10),
            ],
          ],
        ),
        const SizedBox(height: 18),
        AmountEntryCard(
          title: tr('Цена за 1 пассажира'),
          placeholder: _currency == ResidenceCountry.tajikistan
              ? tr('Например, 80')
              : tr('Например, 180000'),
          currencyCode: _currency.currencyCode,
          controller: _priceController,
          onChanged: (value) {
            final amount =
                CreateRideFlow.sanitizedAmount(value, max: _priceMax);
            final text = amount == 0 && value.trim().isEmpty ? '' : '$amount';
            if (text != value) {
              _priceController.value = TextEditingValue(
                text: text,
                selection: TextSelection.collapsed(offset: text.length),
              );
            }
            setState(() {});
          },
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Text(tr('За 1 пассажира'), style: HSText.headline),
            const Spacer(),
            Text(
              _currency.formatAmount(_priceValue),
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 16),
        PrimaryFilledButton(
          label: tr('Продолжить'),
          onPressed: _priceValue > 0 ? _advance : null,
        ),
      ],
    );
  }

  Widget _notesStep(TravelMode mode) {
    final hs = context.hs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          mode == TravelMode.driver
              ? tr('Комментарий к поездке')
              : tr('Комментарий для водителя'),
          style: HSText.headline,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: hs.secondarySurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: hs.stroke),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _notesController,
                minLines: 4,
                maxLines: 6,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: tr('Введите текст'),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                mode == TravelMode.driver
                    ? tr('Добавьте место встречи, багаж и другие детали.')
                    : tr('Напишите, где удобно встретиться и сколько багажа с собой.'),
                style: HSText.footnote.copyWith(color: context.secondaryText),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PrimaryFilledButton(label: tr('Продолжить'), onPressed: _advance),
      ],
    );
  }

  Widget _summaryStep(TravelMode mode) {
    final isDriver = mode == TravelMode.driver;
    final accent = isDriver ? context.hs.primary : context.hs.passenger;
    final notes = _notesController.text.trim();

    final meetingRows = <Widget>[];
    if (_draft.isCustomDepartureMeetingSelected &&
        _draft.customDepartureMeetingText.trim().isNotEmpty) {
      meetingRows.add(
        MeetingPlaceSummaryRow(
          title: tr('Точка встречи'),
          city: _draft.departureLocation.city.name,
          value: _draft.customDepartureMeetingText.trim(),
          accent: context.hs.primary,
        ),
      );
    } else if (_draft.selectedDepartureMeetingPoint != null) {
      final point = _draft.selectedDepartureMeetingPoint!;
      meetingRows.add(
        MeetingPlaceSummaryRow(
          title: tr('Точка встречи'),
          city: _draft.departureLocation.city.name,
          value: point.addressLine ?? point.title,
          accent: context.hs.primary,
        ),
      );
    }
    if (_draft.isCustomArrivalMeetingSelected &&
        _draft.customArrivalMeetingText.trim().isNotEmpty) {
      meetingRows.add(
        MeetingPlaceSummaryRow(
          title: tr('Точка прибытия'),
          city: _draft.destinationLocation.city.name,
          value: _draft.customArrivalMeetingText.trim(),
          accent: context.hs.passenger,
        ),
      );
    } else if (_draft.selectedArrivalMeetingPoint != null) {
      final point = _draft.selectedArrivalMeetingPoint!;
      meetingRows.add(
        MeetingPlaceSummaryRow(
          title: tr('Точка прибытия'),
          city: _draft.destinationLocation.city.name,
          value: point.addressLine ?? point.title,
          accent: context.hs.passenger,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CreateSummaryRouteHero(
          accent: accent,
          badgeTitle: isDriver ? tr('Проверка поездки') : tr('Проверка запроса'),
          fromCity: _draft.departureLocation.city.name,
          toCity: _draft.destinationLocation.city.name,
          fromCountry: _draft.departureLocation.country.name,
          toCountry: _draft.destinationLocation.country.name,
        ),
        const SizedBox(height: 18),
        Column(
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: CreateSummaryMetricCard(
                      title: tr('Дата'),
                      value: DateTextFormatter.dayMonthYear(_draft.departureDate),
                      icon: Icons.calendar_today,
                      accent: accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CreateSummaryMetricCard(
                      title: tr('Время'),
                      value: DateTextFormatter.time(_draft.departureTime),
                      icon: Icons.schedule,
                      accent: accent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: CreateSummaryMetricCard(
                      title: isDriver ? tr('Цена за место') : tr('Формат'),
                      value: isDriver
                          ? _currency.formatAmount(_priceValue)
                          : tr('Без бюджета'),
                      icon: isDriver
                          ? Icons.payments_outlined
                          : Icons.verified_user,
                      accent: accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CreateSummaryMetricCard(
                      title: isDriver ? tr('Свободные места') : tr('Нужно мест'),
                      value:
                          '${isDriver ? _draft.availableSeatLabels.length : _draft.seats}',
                      icon: Icons.groups,
                      accent: accent,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (isDriver && _draft.maxTwoPassengersInBack) ...[
          const SizedBox(height: 12),
          CreateSummaryMetricCard(
            title: tr('Опция для пассажиров'),
            value: tr('Максимум двое сзади'),
            icon: Icons.check_box_outlined,
            accent: accent,
          ),
        ],
        if (isDriver && _draft.instantBookingEnabled) ...[
          const SizedBox(height: 12),
          CreateSummaryMetricCard(
            title: tr('Бронирование'),
            value: tr('Мгновенная бронь'),
            icon: Icons.bolt,
            accent: accent,
          ),
        ],
        if (meetingRows.isNotEmpty) ...[
          const SizedBox(height: 18),
          Row(
            children: [
              Icon(
                Icons.place_outlined,
                size: 16,
                color: context.secondaryText,
              ),
              const SizedBox(width: 6),
              Text(
                tr('Точки встречи'),
                style: HSText.subheadlineSemibold.copyWith(
                  color: context.secondaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final row in meetingRows) ...[row, const SizedBox(height: 10)],
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(Icons.notes, size: 16, color: context.secondaryText),
            const SizedBox(width: 6),
            Text(
              tr('Комментарий'),
              style: HSText.subheadlineSemibold.copyWith(
                color: context.secondaryText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.hs.secondarySurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.hs.stroke),
          ),
          child: Text(
            notes.isEmpty ? tr('Без дополнительного комментария') : notes,
            style: HSText.subheadline,
          ),
        ),
        const SizedBox(height: 18),
        PrimaryFilledButton(
          label: isDriver
              ? tr('Опубликовать поездку')
              : tr('Опубликовать запрос'),
          accent: accent,
          isLoading: _isPublishing,
          onPressed: _isPublishing ? null : _publish,
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // Passenger request form (single page)
  // --------------------------------------------------------------------------

  Widget _buildPassengerForm() {
    final hs = context.hs;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _resetFlow,
                child: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: hs.cardBackground,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chevron_left, size: 22),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('Создать заявку'),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tr('Укажите маршрут, время и комментарий для водителя.'),
                      style: HSText.subheadline.copyWith(
                        color: context.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            tr('Маршрут'),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          WizardFieldRow(
            icon: Icons.trip_origin,
            iconColor: hs.primary,
            value: _draft.hasSelectedPassengerFrom
                ? _draft.departureLocation.city.name
                : null,
            placeholder: tr('Откуда'),
            onTap: () => _pickLocation(isFrom: true, isDriver: false),
          ),
          const SizedBox(height: 14),
          WizardFieldRow(
            icon: Icons.location_on,
            iconColor: hs.orange,
            value: _draft.hasSelectedPassengerTo
                ? _draft.destinationLocation.city.name
                : null,
            placeholder: tr('Куда'),
            onTap: () => _pickLocation(isFrom: false, isDriver: false),
          ),
          const SizedBox(height: 14),
          WizardFieldRow(
            icon: Icons.calendar_today,
            iconColor: hs.primary,
            value: _passengerDateLabel(),
            placeholder: tr('Когда'),
            onTap: _pickDate,
          ),
          const SizedBox(height: 14),
          WizardFieldRow(
            icon: Icons.schedule,
            iconColor: hs.primary,
            value: DateTextFormatter.time(_draft.departureTime),
            placeholder: tr('Время'),
            onTap: () => showWizardTimePicker(
              context,
              title: tr('Время'),
              initial: _draft.departureTime,
              onChanged: (value) =>
                  setState(() => _draft.departureTime = value),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            tr('Сколько нужно мест'),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          CreateCounterSelector(
            value: _draft.seats.clamp(1, 4),
            min: 1,
            max: 4,
            onChanged: (value) => setState(() => _draft.seats = value),
          ),
          const SizedBox(height: 22),
          Text(
            tr('Комментарий'),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: hs.secondarySurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: hs.stroke),
            ),
            child: TextField(
              controller: _notesController,
              minLines: 5,
              maxLines: 8,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.all(14),
                border: InputBorder.none,
                hintText: tr(
                  'Напишите, нужно ли забрать вас с адреса, будет ли у вас '
                  'большой багаж или другие важные детали',
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          PrimaryFilledButton(
            label: tr('Создать заявку'),
            accent: hs.passenger,
            isLoading: _isPublishing,
            // "Откуда" and "Куда" are required before a request can be created.
            onPressed: (_isPublishing ||
                    !_draft.hasSelectedPassengerFrom ||
                    !_draft.hasSelectedPassengerTo)
                ? null
                : _publish,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  String? _passengerDateLabel() {
    final date = _draft.departureDate;
    if (DateUtilsX.isToday(date)) return tr('Сегодня');
    if (DateUtilsX.isTomorrow(date)) return tr('Завтра');
    return DateTextFormatter.dayMonthYear(date);
  }
}

/// Small pill used to pick the ride's pricing currency (QA #99).
class _CurrencyChip extends StatelessWidget {
  const _CurrencyChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? hs.primary : hs.secondarySurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? hs.primary : hs.stroke),
        ),
        child: Text(
          label,
          style: HSText.subheadlineSemibold.copyWith(
            color: isSelected ? Colors.white : context.primaryText,
          ),
        ),
      ),
    );
  }
}
