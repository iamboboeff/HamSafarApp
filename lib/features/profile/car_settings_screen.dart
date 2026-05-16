import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/app_backdrop.dart';
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
    setState(() => _isSaving = true);
    final car = ref.read(carProfileProvider);
    String title = 'Автомобиль обновлён';
    String message = 'Данные автомобиля сохранены.';
    try {
      await ref.read(sessionProvider.notifier).updateCar(
            car.copyWith(
              model: _model.text.trim(),
              color: _color.text.trim(),
              plateNumber: _plate.text.trim(),
            ),
          );
    } catch (e) {
      title = 'Не удалось сохранить';
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
            child: const Text('Ок'),
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
      appBar: AppBar(title: const Text('Автомобиль')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AppBackdrop(),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Автомобиль', style: HSText.headline),
                const SizedBox(height: 18),
                SimpleProfileInput(
                  title: 'Марка и модель',
                  child: TextField(
                    controller: _model,
                    decoration: const InputDecoration.collapsed(
                      hintText: 'Например, Chevrolet Cobalt',
                    ),
                    style: HSText.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 16),
                SimpleProfileInput(
                  title: 'Цвет',
                  child: TextField(
                    controller: _color,
                    decoration: const InputDecoration.collapsed(
                      hintText: 'Например, Белый',
                    ),
                    style: HSText.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 16),
                SimpleProfileInput(
                  title: 'Номер',
                  child: TextField(
                    controller: _plate,
                    decoration: const InputDecoration.collapsed(
                      hintText: 'Например, 1234 AA',
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
            Divider(height: 1, color: hs.stroke.withValues(alpha: 0.9)),
            Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                14,
                20,
                12 + MediaQuery.of(context).padding.bottom,
              ),
              child: PrimaryFilledButton(
                label: 'Сохранить автомобиль',
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
