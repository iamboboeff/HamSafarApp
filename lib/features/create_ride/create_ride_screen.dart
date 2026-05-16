import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import '../../widgets/month_calendar.dart';
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
  final CreateRideDraft _draft = CreateRideDraft();
  bool _isPublishing = false;
  bool _didApplyDefaults = false;

  final _priceController = TextEditingController();
  final _notesController = TextEditingController();
  final _customDepartureController = TextEditingController();
  final _customArrivalController = TextEditingController();

  @override
  void dispose() {
    _priceController.dispose();
    _notesController.dispose();
    _customDepartureController.dispose();
    _customArrivalController.dispose();
    super.dispose();
  }

  ResidenceCountry get _currency => ref.read(residenceCountryProvider);

  int get _priceValue => CreateRideFlow.sanitizedAmount(_priceController.text);

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
    setState(() {
      if (mode == TravelMode.driver) {
        _draft.seats = _driverSeatLimit;
        _syncDriverSeats();
        _draft.hasSelectedDriverFrom = false;
        _draft.hasSelectedDriverTo = false;
        _flow = const CreateFlowState(CreateFlowPhase.driver);
      } else {
        _draft.seats = 1;
        _draft.hasSelectedPassengerFrom = false;
        _draft.hasSelectedPassengerTo = false;
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
      title: isFrom ? 'Откуда' : 'Куда',
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
    if (_mergedDepartureDate.isBefore(DateTime.now())) {
      _showError('Нельзя создать поездку на прошедшие дату или время.');
      return;
    }
    if (mode == TravelMode.driver && _priceValue < 1) {
      _showError('Сумма должна быть от 1 до 1000.');
      return;
    }

    setState(() => _isPublishing = true);
    final service = ref.read(supabaseServiceProvider);
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
        _showError('Не удалось опубликовать. Попробуйте ещё раз.');
      }
      return;
    }

    if (!mounted) return;
    setState(() => _isPublishing = false);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Поездка опубликована'),
        content: Text(
          mode == TravelMode.driver
              ? 'Ваша поездка теперь доступна пассажирам.'
              : 'Ваш запрос опубликован. Водители смогут связаться с вами.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Закрыть'),
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

  void _resetFlow() {
    setState(() {
      _flow = const CreateFlowState.roleSelection();
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
        title: const Text('Не удалось опубликовать'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Ок'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _ensureDefaults();
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
            title: step.title(TravelMode.driver),
            subtitle: step.subtitle(TravelMode.driver),
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
          placeholder: 'Откуда',
          onTap: () => _pickLocation(isFrom: true, isDriver: true),
        ),
        const SizedBox(height: 16),
        MeetingPlaceSelectorCard(
          title: 'Место встречи',
          subtitle: 'Необязательно',
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
        PrimaryFilledButton(label: 'Продолжить', onPressed: _advance),
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
          placeholder: 'Куда',
          onTap: () => _pickLocation(isFrom: false, isDriver: true),
        ),
        const SizedBox(height: 16),
        MeetingPlaceSelectorCard(
          title: 'Место прибытия',
          subtitle: 'Необязательно',
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
        PrimaryFilledButton(label: 'Продолжить', onPressed: _advance),
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
          title: 'Дата поездки',
          value: DateTextFormatter.dayMonthYear(_draft.departureDate),
          icon: Icons.calendar_today,
        ),
        const SizedBox(height: 18),
        Text(
          mode == TravelMode.driver
              ? 'Во сколько заберёте пассажиров?'
              : 'Во сколько хотите выехать?',
          style: HSText.headline,
        ),
        const SizedBox(height: 8),
        Text(
          mode == TravelMode.driver
              ? 'Пассажиры увидят точное время отправления.'
              : 'Выберите удобное время, чтобы водителям было проще откликнуться.',
          style: HSText.subheadline.copyWith(color: context.secondaryText),
        ),
        const SizedBox(height: 18),
        CreateTimeSelectionCard(
          title: mode == TravelMode.driver ? 'Время выезда' : 'Удобное время',
          time: _draft.departureTime,
          onChanged: (value) => setState(() => _draft.departureTime = value),
        ),
        const SizedBox(height: 16),
        PrimaryFilledButton(label: 'Продолжить', onPressed: _advance),
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
              ? 'Сколько попутчиков возьмёте в дорогу?'
              : 'Сколько мест вам нужно?',
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
            'Свободных мест: ${_draft.seats}',
            style: HSText.subheadline.copyWith(color: context.secondaryText),
          ),
          const SizedBox(height: 16),
          CreateCheckboxOptionCard(
            title: 'Максимум двое сзади',
            subtitle: 'Пустое сиденье посередине делает поездку комфортнее.',
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
            title: 'Мгновенная бронь',
            subtitle: 'Пассажиры бронируют сразу, без ожидания подтверждения.',
            isSelected: _draft.instantBookingEnabled,
            trailingIcon: Icons.bolt,
            onTap: () => setState(() {
              _draft.instantBookingEnabled = !_draft.instantBookingEnabled;
            }),
          ),
        ],
        const SizedBox(height: 16),
        PrimaryFilledButton(label: 'Продолжить', onPressed: _advance),
      ],
    );
  }

  Widget _priceStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Укажите цену за одно место', style: HSText.headline),
        const SizedBox(height: 8),
        Text(
          'Пассажиры увидят стоимость за одного человека.',
          style: HSText.subheadline.copyWith(color: context.secondaryText),
        ),
        const SizedBox(height: 18),
        AmountEntryCard(
          title: 'Цена за 1 пассажира',
          placeholder: _currency == ResidenceCountry.tajikistan
              ? 'Например, 80'
              : 'Например, 180000',
          currencyCode: _currency.currencyCode,
          controller: _priceController,
          onChanged: (value) {
            final amount = CreateRideFlow.sanitizedAmount(value);
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
            Text('За 1 пассажира', style: HSText.headline),
            const Spacer(),
            Text(
              _currency.formatAmount(_priceValue),
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 16),
        PrimaryFilledButton(
          label: 'Продолжить',
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
              ? 'Комментарий к поездке'
              : 'Комментарий для водителя',
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
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Введите текст',
                ),
              ),
              const SizedBox(height: 10),
              Text(
                mode == TravelMode.driver
                    ? 'Добавьте место встречи, багаж и другие детали.'
                    : 'Напишите, где удобно встретиться и сколько багажа с собой.',
                style: HSText.footnote.copyWith(color: context.secondaryText),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PrimaryFilledButton(label: 'Продолжить', onPressed: _advance),
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
          title: 'Точка встречи',
          city: _draft.departureLocation.city.name,
          value: _draft.customDepartureMeetingText.trim(),
          accent: context.hs.primary,
        ),
      );
    } else if (_draft.selectedDepartureMeetingPoint != null) {
      final point = _draft.selectedDepartureMeetingPoint!;
      meetingRows.add(
        MeetingPlaceSummaryRow(
          title: 'Точка встречи',
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
          title: 'Точка прибытия',
          city: _draft.destinationLocation.city.name,
          value: _draft.customArrivalMeetingText.trim(),
          accent: context.hs.passenger,
        ),
      );
    } else if (_draft.selectedArrivalMeetingPoint != null) {
      final point = _draft.selectedArrivalMeetingPoint!;
      meetingRows.add(
        MeetingPlaceSummaryRow(
          title: 'Точка прибытия',
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
          badgeTitle: isDriver ? 'Проверка поездки' : 'Проверка запроса',
          fromCity: _draft.departureLocation.city.name,
          toCity: _draft.destinationLocation.city.name,
          fromCountry: _draft.departureLocation.country.name,
          toCountry: _draft.destinationLocation.country.name,
        ),
        const SizedBox(height: 18),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.35,
          children: [
            CreateSummaryMetricCard(
              title: 'Дата',
              value: DateTextFormatter.dayMonthYear(_draft.departureDate),
              icon: Icons.calendar_today,
              accent: accent,
            ),
            CreateSummaryMetricCard(
              title: 'Время',
              value: DateTextFormatter.time(_draft.departureTime),
              icon: Icons.schedule,
              accent: accent,
            ),
            CreateSummaryMetricCard(
              title: isDriver ? 'Цена за место' : 'Формат',
              value: isDriver
                  ? _currency.formatAmount(_priceValue)
                  : 'Без бюджета',
              icon: isDriver ? Icons.payments_outlined : Icons.verified_user,
              accent: accent,
            ),
            CreateSummaryMetricCard(
              title: isDriver ? 'Свободные места' : 'Нужно мест',
              value:
                  '${isDriver ? _draft.availableSeatLabels.length : _draft.seats}',
              icon: Icons.groups,
              accent: accent,
            ),
          ],
        ),
        if (isDriver && _draft.maxTwoPassengersInBack) ...[
          const SizedBox(height: 12),
          CreateSummaryMetricCard(
            title: 'Опция для пассажиров',
            value: 'Максимум двое сзади',
            icon: Icons.check_box_outlined,
            accent: accent,
          ),
        ],
        if (isDriver && _draft.instantBookingEnabled) ...[
          const SizedBox(height: 12),
          CreateSummaryMetricCard(
            title: 'Бронирование',
            value: 'Мгновенная бронь',
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
                'Точки встречи',
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
              'Комментарий',
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
            notes.isEmpty ? 'Без дополнительного комментария' : notes,
            style: HSText.subheadline,
          ),
        ),
        const SizedBox(height: 18),
        PrimaryFilledButton(
          label: isDriver ? 'Опубликовать поездку' : 'Опубликовать запрос',
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
                    const Text(
                      'Создать заявку',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Укажите маршрут, время и комментарий для водителя.',
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
          const Text(
            'Маршрут',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          WizardFieldRow(
            icon: Icons.trip_origin,
            iconColor: hs.primary,
            value: _draft.hasSelectedPassengerFrom
                ? _draft.departureLocation.city.name
                : null,
            placeholder: 'Откуда',
            onTap: () => _pickLocation(isFrom: true, isDriver: false),
          ),
          const SizedBox(height: 14),
          WizardFieldRow(
            icon: Icons.location_on,
            iconColor: hs.orange,
            value: _draft.hasSelectedPassengerTo
                ? _draft.destinationLocation.city.name
                : null,
            placeholder: 'Куда',
            onTap: () => _pickLocation(isFrom: false, isDriver: false),
          ),
          const SizedBox(height: 14),
          WizardFieldRow(
            icon: Icons.calendar_today,
            iconColor: hs.primary,
            value: _passengerDateLabel(),
            placeholder: 'Когда',
            onTap: _pickDate,
          ),
          const SizedBox(height: 14),
          WizardFieldRow(
            icon: Icons.schedule,
            iconColor: hs.primary,
            value: DateTextFormatter.time(_draft.departureTime),
            placeholder: 'Время',
            onTap: () => showWizardTimePicker(
              context,
              title: 'Время',
              initial: _draft.departureTime,
              onChanged: (value) =>
                  setState(() => _draft.departureTime = value),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Сколько нужно мест',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          CreateCounterSelector(
            value: _draft.seats.clamp(1, 4),
            min: 1,
            max: 4,
            onChanged: (value) => setState(() => _draft.seats = value),
          ),
          const SizedBox(height: 22),
          const Text(
            'Комментарий',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
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
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.all(14),
                border: InputBorder.none,
                hintText:
                    'Напишите, нужно ли забрать вас с адреса, будет ли у вас '
                    'большой багаж или другие важные детали',
              ),
            ),
          ),
          const SizedBox(height: 22),
          PrimaryFilledButton(
            label: 'Создать заявку',
            accent: hs.passenger,
            isLoading: _isPublishing,
            onPressed: _isPublishing ? null : _publish,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  String? _passengerDateLabel() {
    final date = _draft.departureDate;
    if (DateUtilsX.isToday(date)) return 'Сегодня';
    if (DateUtilsX.isTomorrow(date)) return 'Завтра';
    return DateTextFormatter.dayMonthYear(date);
  }
}
