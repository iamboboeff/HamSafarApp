import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../state/app_state.dart';
import '../../../theme/app_dimens.dart';
import '../../../theme/app_text.dart';

/// Ported from `HomeHeaderView` in `HomeViews.swift`.
class HomeHeader extends ConsumerWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    final name = ref.watch(currentUserProvider).name.trim();
    final greeting = isAuthenticated && name.isNotEmpty
        ? 'Здравствуйте, $name!'
        : 'Здравствуйте!';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(greeting, style: HSText.largeTitle),
        const SizedBox(height: HSSpacing.item),
        Text(
          'Междугородние маршруты без звонков и долгих согласований.',
          style: HSText.subheadline.copyWith(color: context.secondaryText),
        ),
      ],
    );
  }
}
