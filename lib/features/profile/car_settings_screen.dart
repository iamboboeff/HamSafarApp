import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hamsafar/core/i18n/l10n.dart';

import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/buttons.dart';
import 'widgets/profile_widgets.dart';

/// Ported from `CarSettingsView` in `ProfileViews.swift`.
class CarSettingsScreen extends ConsumerStatefulWidget {
  const CarSettingsScreen({super.key});

  @override
  ConsumerState<CarSettingsScreen> createState() => _CarSettingsScreenState();
}

class _CarSettingsScreenState extends ConsumerState<CarSettingsScreen> {
  late final TextEditingController _model;
  late final TextEditingController _color;
  late final TextEditingController _plate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final car = ref.read(carProfileProvider);
    _model = TextEditingController(text: car.model);
    _color = TextEditingController(text: car.color);
    _plate = TextEditingController(text: car.plateNumber);
  }

  @override
  void dispose() {
    _model.dispose();
    _color.dispose();
    _plate.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final model = _model.text.trim();
    final color = _color.text.trim();
    final plate = _plate.text.trim();
    // All vehicle fields are required and bounded — passengers see this data
    // on every ride, so it can't be empty or junk (QA #91).
    final problem = _validateCar(model: model, color: color, plate: plate);
    if (problem != null) {
      await _showValidationDialog(problem);
      return;
    }

    setState(() => _isSaving = true);
    final car = ref.read(carProfileProvider);
    String title = tr('Автомобиль обновлён');
    String message = tr('Данные автомобиля сохранены.');
    try {
      await ref.read(sessionProvider.notifier).updateCar(
            car.copyWith(model: model, color: color, plateNumber: plate),
          );
    } catch (e) {
      title = tr('Не удалось сохранить');
      message = e.toString();
    }
    if (!mounted) return;
    setState(() => _isSaving = false);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
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

  String? _validateCar({
    required String model,
    required String color,
    required String plate,
  }) {
    if (model.isEmpty) return tr('Укажите марку и модель автомобиля.');
    if (model.length > 50) return tr('Марка и модель: не больше 50 символов.');
    if (color.isEmpty) return tr('Укажите цвет автомобиля.');
    if (color.length > 30) return tr('Цвет: не больше 30 символов.');
    // A colour can't be just digits — "12345" is not a colour (QA #91).
    if (RegExp(r'^[0-9]+$').hasMatch(color)) {
      return tr('Цвет: введите название цвета, а не число.');
    }
    if (plate.isEmpty) return tr('Укажите номер автомобиля.');
    if (plate.length > 15) return tr('Номер: не больше 15 символов.');
    return null;
  }

  Future<void> _showValidationDialog(String message) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('Проверьте данные')),
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

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(tr('Автомобиль'))),
      body: Stack(
        fit: StackFit.expand,
        children: [
          SingleChildScrollView(
            // Left/right safe-area insets for landscape notch / Island (QA #93).
            padding: EdgeInsets.fromLTRB(
              20 + MediaQuery.paddingOf(context).left,
              20,
              20 + MediaQuery.paddingOf(context).right,
              120,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('Автомобиль'), style: HSText.headline),
                const SizedBox(height: 18),
                SimpleProfileInput(
                  title: tr('Марка и модель'),
                  child: TextField(
                    controller: _model,
                    inputFormatters: [LengthLimitingTextInputFormatter(50)],
                    decoration: InputDecoration.collapsed(
                      hintText: tr('Например, Chevrolet Cobalt'),
                    ),
                    style: HSText.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 16),
                SimpleProfileInput(
                  title: tr('Цвет'),
                  child: TextField(
                    controller: _color,
                    inputFormatters: [LengthLimitingTextInputFormatter(30)],
                    decoration: InputDecoration.collapsed(
                      hintText: tr('Например, Белый'),
                    ),
                    style: HSText.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 16),
                SimpleProfileInput(
                  title: tr('Номер'),
                  child: TextField(
                    controller: _plate,
                    inputFormatters: [LengthLimitingTextInputFormatter(15)],
                    decoration: InputDecoration.collapsed(
                      hintText: tr('Например, 1234 AA'),
                    ),
                    style: HSText.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        color: hs.cardBackground,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Divider(height: 1, color: hs.stroke),
            Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                14,
                20,
                12 + MediaQuery.of(context).padding.bottom,
              ),
              child: PrimaryFilledButton(
                label: tr('Сохранить автомобиль'),
                isLoading: _isSaving,
                onPressed: _isSaving ? null : _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
