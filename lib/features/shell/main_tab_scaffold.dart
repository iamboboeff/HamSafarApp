import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/l10n.dart';
import '../../models/app_tab.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/hs_route.dart';
import '../auth/auth_screen.dart';
import '../chat/chat_list_screen.dart';
import '../create_ride/create_ride_screen.dart';
import '../home/home_screen.dart';
import '../profile/profile_screen.dart';
import '../trips/my_trips_screen.dart';

/// Ported from `MainTabView` in `RootShellViews.swift` — the five-tab shell.
class MainTabScaffold extends ConsumerWidget {
  const MainTabScaffold({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTab = ref.watch(selectedTabProvider);
    final tabs = AppTab.values;
    final currentIndex = tabs.indexOf(selectedTab);
    // Every tab reserves the tab bar's space (the "barrier"), so no screen's
    // bottom buttons/content can slide under the bar. The bar itself still
    // renders translucent — `extendBody` is left at its default (false), which
    // only controls whether the body paints behind the bar, not its opacity.
    final tabStack = IndexedStack(
      index: currentIndex,
      children: const [
        HomeScreen(),
        MyTripsScreen(),
        CreateRideScreen(),
        ChatListScreen(),
        ProfileScreen(),
      ],
    );

    // The shell is a single route (tabs are an IndexedStack, sub-flows like the
    // create wizard advance via state), so without this the Android system-back
    // button has nothing to pop and just backgrounds the app (QA #69). Pushed
    // detail screens sit on routes above this one and still pop normally — this
    // only governs back while the tab shell itself is on top.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleSystemBack(ref);
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: tabStack,
        bottomNavigationBar: _HSTabBar(
          currentIndex: currentIndex,
          tabs: tabs,
          onTap: (i) {
            final tab = tabs[i];
            // Guest gating (BlaBlaCar-style, QA #16): the create / trips / chat
            // tabs require an account. Instead of switching, open the auth
            // screen and leave the current tab as-is. Home + Profile stay open
            // to guests (Profile has its own sign-in card).
            // Create is NOT gated here: a guest opens the role picker, and the
            // auth sheet is triggered only when they pick "Я водитель" /
            // "Я пассажир" (see _selectRole in create_ride_screen.dart).
            const gatedTabs = {AppTab.trips, AppTab.inbox};
            if (gatedTabs.contains(tab) && !ref.read(isAuthenticatedProvider)) {
              Navigator.of(context).push(
                HSRoute<void>(
                  builder: (_) => const AuthScreen(),
                  fullscreenDialog: true,
                ),
              );
              return;
            }
            // Tapping "+" always opens a fresh create form (resets the wizard),
            // even if it's already the active tab.
            if (tab == AppTab.create) {
              ref.read(createTabResetProvider.notifier).trigger();
            }
            ref.read(selectedTabProvider.notifier).select(tab);
          },
        ),
      ),
    );
  }

  void _handleSystemBack(WidgetRef ref) {
    final tab = ref.read(selectedTabProvider);
    // 1) Let the active tab consume the back (the create wizard steps back).
    if (tab == AppTab.create) {
      final handler = ref.read(inTabBackHandlerProvider);
      if (handler != null && handler()) return;
    }
    // 2) Any non-home tab returns to Home first.
    if (tab != AppTab.home) {
      ref.read(selectedTabProvider.notifier).select(AppTab.home);
      return;
    }
    // 3) On Home with nothing left to pop — leave the app.
    SystemNavigator.pop();
  }
}

/// Modern iOS-style frosted glass tab bar.
class _HSTabBar extends StatelessWidget {
  const _HSTabBar({
    required this.currentIndex,
    required this.tabs,
    required this.onTap,
  });

  final int currentIndex;
  final List<AppTab> tabs;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final centerIndex = tabs.length ~/ 2;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: hs.cardBackground.withValues(alpha: 0.72),
            border: Border(top: BorderSide(color: hs.stroke, width: 0.5)),
          ),
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: SizedBox(
              height: 56,
              child: Row(
                children: [
                  for (int i = 0; i < tabs.length; i++)
                    Expanded(
                      child: _TabItem(
                        tab: tabs[i],
                        isSelected: i == currentIndex,
                        isCenter: i == centerIndex,
                        onTap: () => onTap(i),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.tab,
    required this.isSelected,
    required this.isCenter,
    required this.onTap,
  });

  final AppTab tab;
  final bool isSelected;
  final bool isCenter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    final color = isSelected ? hs.primary : context.secondaryText;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isCenter) ...[
            // Center "Create" tab — filled circle button
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isSelected
                    ? hs.primary
                    : hs.primary.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSelected ? tab.selectedIcon : tab.icon,
                size: 20,
                color: isSelected ? Colors.white : hs.primary,
              ),
            ),
          ] else ...[
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Icon(
                isSelected ? tab.selectedIcon : tab.icon,
                key: ValueKey(isSelected),
                size: 22,
                color: color,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 160),
              style: TextStyle(
                fontSize: 10,
                fontFamily: 'Manrope',
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
              child: Text(tr(tab.title)),
            ),
          ],
        ],
      ),
    );
  }
}
