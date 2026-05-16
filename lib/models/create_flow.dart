import 'app_tab.dart';

/// Ported from `CreateWizardStep` in `CreateRideViews.swift`.
enum CreateWizardStep {
  from,
  to,
  date,
  time,
  seats,
  price,
  notes,
  summary;

  double get progress => (index + 1) / CreateWizardStep.values.length;

  CreateWizardStep get next {
    final all = CreateWizardStep.values;
    return all[(index + 1).clamp(0, all.length - 1)];
  }

  CreateWizardStep get previous {
    final all = CreateWizardStep.values;
    return all[(index - 1).clamp(0, all.length - 1)];
  }

  String title(TravelMode mode) => switch (this) {
    CreateWizardStep.from =>
      mode == TravelMode.driver ? 'Откуда поедете?' : 'Откуда выезжаете?',
    CreateWizardStep.to => 'Куда направляетесь?',
    CreateWizardStep.date => 'Когда поедете?',
    CreateWizardStep.time =>
      mode == TravelMode.driver ? 'Во сколько выезд?' : 'Какое время удобно?',
    CreateWizardStep.seats => 'Количество мест',
    CreateWizardStep.price => 'Оплата',
    CreateWizardStep.notes =>
      mode == TravelMode.driver
          ? 'Комментарий к поездке'
          : 'Комментарий к запросу',
    CreateWizardStep.summary =>
      mode == TravelMode.driver ? 'Проверьте поездку' : 'Проверьте запрос',
  };

  String subtitle(TravelMode mode) => switch (this) {
    CreateWizardStep.from => 'Укажите город отправления.',
    CreateWizardStep.to => 'Выберите город прибытия.',
    CreateWizardStep.date => 'Сначала выберите день поездки.',
    CreateWizardStep.time =>
      mode == TravelMode.driver
          ? 'Пассажиры увидят точное время выезда.'
          : 'Выберите удобное время отправления.',
    CreateWizardStep.seats =>
      mode == TravelMode.driver
          ? 'Сколько мест доступно в машине.'
          : 'Сколько мест вам потребуется.',
    CreateWizardStep.price => 'Настройте цену за одного пассажира.',
    CreateWizardStep.notes => 'Добавьте важные детали поездки.',
    CreateWizardStep.summary =>
      'Перед публикацией проверьте маршрут и условия.',
  };
}

/// The three top-level phases of the Create flow.
enum CreateFlowPhase { roleSelection, driver, passenger }

/// Ported from `CreateFlowState` in `CreateRideViews.swift` — a phase plus,
/// for the driver/passenger phases, the active wizard step.
class CreateFlowState {
  const CreateFlowState(this.phase, [this.step = CreateWizardStep.from]);

  const CreateFlowState.roleSelection()
    : phase = CreateFlowPhase.roleSelection,
      step = CreateWizardStep.from;

  final CreateFlowPhase phase;
  final CreateWizardStep step;

  TravelMode? get mode => switch (phase) {
    CreateFlowPhase.roleSelection => null,
    CreateFlowPhase.driver => TravelMode.driver,
    CreateFlowPhase.passenger => TravelMode.passenger,
  };

  @override
  bool operator ==(Object other) =>
      other is CreateFlowState && other.phase == phase && other.step == step;

  @override
  int get hashCode => Object.hash(phase, step);
}
