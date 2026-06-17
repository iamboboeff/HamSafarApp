import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_navigator.dart';
import 'core/push/push_notifications_service.dart';
import 'features/activity/activity_notifications_screen.dart';
import 'features/chat/chat_detail_screen.dart';
import 'features/search/search_results_screen.dart';
import 'features/shell/launch_splash.dart';
import 'features/shell/main_tab_scaffold.dart';
import 'models/app_tab.dart';
import 'models/location.dart';
import 'state/activity_state.dart';
import 'state/app_state.dart';
import 'state/chat_state.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'widgets/app_backdrop.dart';

/// Ported from `HamSafarApp` in `HamSafarApp.swift`.
class HamSafarApp extends ConsumerStatefulWidget {
  const HamSafarApp({super.key});

  @override
  ConsumerState<HamSafarApp> createState() => _HamSafarAppState();
}

class _HamSafarAppState extends ConsumerState<HamSafarApp>
    with WidgetsBindingObserver {
  StreamSubscription<Map<String, dynamic>>? _pushOpenedSub;
  StreamSubscription<InAppMessage>? _bannerSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Navigate when the user taps a push notification (QA #25).
    _pushOpenedSub =
        PushNotificationsService.instance.openedMessages.listen(_handlePushOpened);
    // Show a tappable in-app banner for a new message while on another page.
    _bannerSub = inAppMessages.stream.listen((m) {
      if (!mounted) return;
      showInAppMessageBanner(
        title: m.title,
        body: m.body,
        onTap: () => _openChatThread(m.localThreadId),
      );
    });
    // Handle a tap that cold-started the app from a terminated state.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PushNotificationsService.instance.processInitialMessage();
    });
  }

  @override
  void dispose() {
    _pushOpenedSub?.cancel();
    _bannerSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Routes a notification tap to the relevant screen based on its payload.
  /// Chat pushes carry `scope:'chat'` + `thread_id` (see the backend
  /// enqueue_* functions); booking pushes may have an empty thread_id.
  void _handlePushOpened(Map<String, dynamic> data) {
    if (!ref.read(sessionProvider).isAuthenticated) return;
    final scope = (data['scope'] ?? '').toString();
    final threadId = (data['thread_id'] ?? '').toString();

    // A real chat thread → open that exact conversation (Telegram-like).
    if (scope == 'chat' && threadId.isNotEmpty) {
      _openChatThread('chat-$threadId');
      return;
    }

    // Ride alert → open the route's search so the user sees the new ride.
    if (scope == 'ride_alert') {
      _openRouteSearch(
        (data['from_city'] ?? '').toString(),
        (data['to_city'] ?? '').toString(),
      );
      return;
    }

    final nav = navigatorKey.currentState;
    nav?.popUntil((route) => route.isFirst);
    if (scope == 'chat') {
      // Chat-scope without a thread (e.g. a booking notification) → chat list.
      ref.read(selectedTabProvider.notifier).select(AppTab.inbox);
    } else {
      ref.read(activityProvider.notifier).refresh();
      nav?.push(
        MaterialPageRoute<void>(
          builder: (_) => const ActivityNotificationsScreen(),
        ),
      );
    }
  }

  /// Opens the search results for a route (from a ride-alert push tap).
  void _openRouteSearch(String fromCity, String toCity) {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    nav.popUntil((route) => route.isFirst);
    ref.read(selectedTabProvider.notifier).select(AppTab.home);
    if (fromCity.isEmpty || toCity.isEmpty) return;
    ref.read(homeSearchProvider.notifier).applyRoute(
          LocationDirectory.cityNamed(fromCity),
          LocationDirectory.cityNamed(toCity),
        );
    ref
        .read(selectedHomeSectionProvider.notifier)
        .select(HomeListingSection.rides);
    ref.read(marketplaceProvider.notifier).refresh();
    // The alert that triggered this push was auto-removed server-side — re-sync.
    ref.read(rideAlertsProvider.notifier).refresh();
    nav.push(
      MaterialPageRoute<void>(builder: (_) => const SearchResultsScreen()),
    );
  }

  /// Opens a specific chat thread, loading the chat list first if the thread
  /// isn't in memory yet (push tap / banner tap).
  Future<void> _openChatThread(String localThreadId) async {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    nav.popUntil((route) => route.isFirst);
    ref.read(selectedTabProvider.notifier).select(AppTab.inbox);
    final notifier = ref.read(chatProvider.notifier);
    if (notifier.threadById(localThreadId) == null) {
      await notifier.refresh();
    }
    if (!mounted || notifier.threadById(localThreadId) == null) return;
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => ChatDetailScreen(threadId: localThreadId),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back to the foreground (e.g. after tapping a push that was sitting
    // in the tray) — refresh the notification feed / counter and booking
    // statuses so they aren't stale (QA #23).
    if (state == AppLifecycleState.resumed &&
        ref.read(sessionProvider).isAuthenticated) {
      ref.read(activityProvider.notifier).refresh();
      ref.read(bookedTripsProvider.notifier).refresh();
      // Reconcile the chat list too — the realtime websocket may have dropped
      // while the app was backgrounded.
      ref.read(chatProvider.notifier).refresh();
      // Ride alerts are one-shot and auto-removed server-side once a matching
      // ride is published, so re-sync the local list to drop fired ones.
      ref.read(rideAlertsProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appearance = ref.watch(appearanceSettingsProvider);
    return MaterialApp(
      title: 'HamSafar',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: appearance.theme.themeMode,
      // Adaptive system overlay (status bar + Android nav bar) — picks
      // dark icons on light theme, light icons on dark theme. Wrapped
      // here at the root so screens without an AppBar (home, profile,
      // chat list) get the correct look without per-screen wiring.
      builder: (context, child) {
        final hs = context.hs;
        final brightness = Theme.of(context).brightness;
        final overlay = brightness == Brightness.light
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light;
        return GestureDetector(
          // Tap anywhere outside a text field to dismiss the keyboard — applies
          // on every screen because it wraps the whole app at the root.
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlay.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness:
                brightness == Brightness.light
                    ? Brightness.dark
                    : Brightness.light,
          ),
          // Paint the backdrop behind the entire navigator — including the
          // AppBar area — so there is no hard seam between the app bar and
          // the body on any screen.
          child: ColoredBox(
            color: hs.background,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const AppBackdrop(),
                child!,
              ],
            ),
          ),
          ),
        );
      },
      home: const LaunchGate(child: MainTabScaffold()),
    );
  }
}
