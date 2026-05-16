import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_tab.dart';
import '../../state/app_state.dart';
import '../chat/chat_list_screen.dart';
import '../create_ride/create_ride_screen.dart';
import '../home/home_screen.dart';
import '../profile/profile_screen.dart';
import '../trips/my_trips_screen.dart';

/// Ported from `MainTabView` in `RootShellViews.swift` — the five-tab shell.
///
/// Only the Home tab is implemented; the others show [PlaceholderScreen].
/// Search results / ride detail are pushed onto the root navigator from the
/// Home tab, so they cover the tab bar exactly like `toolbar(.hidden)` on iOS.
class MainTabScaffold extends ConsumerWidget {
  const MainTabScaffold({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTab = ref.watch(selectedTabProvider);
    final tabs = AppTab.values;
    final currentIndex = tabs.indexOf(selectedTab);

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: const [
          HomeScreen(),
          MyTripsScreen(),
          CreateRideScreen(),
          ChatListScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) =>
            ref.read(selectedTabProvider.notifier).select(tabs[index]),
        destinations: [
          for (final tab in tabs)
            NavigationDestination(
              icon: Icon(tab.icon),
              selectedIcon: Icon(tab.selectedIcon),
              label: tab.title,
            ),
        ],
      ),
    );
  }
}
