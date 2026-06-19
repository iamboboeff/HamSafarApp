import 'package:hamsafar/core/i18n/l10n.dart';

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
    CreateWizardStep.from => mode == TravelMode.driver
        ? tr('Откуда поедете?')
        : tr('Откуда выезжаете?'),
    CreateWizardStep.to => tr('Куда направляетесь?'),
    CreateWizardStep.date => tr('Когда поедете?'),
    CreateWizardStep.time => mode == TravelMode.driver
        ? tr('Во сколько выезд?')
        : tr('Какое время удобно?'),
    CreateWizardStep.seats => tr('Количество мест'),
    CreateWizardStep.price => tr('Оплата'),
    CreateWizardStep.notes => mode == TravelMode.driver
        ? tr('Комментарий к поездке')
        : tr('Комментарий к запросу'),
    CreateWizardStep.summary => mode == TravelMode.driver
        ? tr('Проверьте поездку')
        : tr('Проверьте запрос'),
  };

  String subtitle(TravelMode mode) => switch (this) {
    CreateWizardStep.from => tr('Укажите город отправления.'),
    CreateWizardStep.to => tr('Выберите город прибытия.'),
    CreateWizardStep.date => tr('Сначала выберите день поездки.'),
    CreateWizardStep.time => mode == TravelMode.driver
        ? tr('Пассажиры увидят точное время выезда.')
        : tr('Выберите удобное время отправления.'),
    CreateWizardStep.seats => mode == TravelMode.driver
        ? tr('Сколько мест доступно в машине.')
        : tr('Сколько мест вам потребуется.'),
    CreateWizardStep.price => tr('Настройте цену за одного пассажира.'),
    CreateWizardStep.notes => tr('Добавьте важные детали поездки.'),
    CreateWizardStep.summary => tr(
      'Перед публикацией проверьте маршрут и условия.',
    ),
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
