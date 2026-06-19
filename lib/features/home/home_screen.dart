import 'package:flutter/material.dart';
import '../../widgets/hs_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/l10n.dart';
import '../../core/net_status.dart';
import '../../domain/home_flow.dart';
import '../../models/app_tab.dart';
import '../../models/ride_search.dart';
import '../../state/activity_state.dart';
import '../../state/app_state.dart';
import '../../theme/app_dimens.dart';
import '../../widgets/app_backdrop.dart';
import '../../widgets/common.dart';
import '../activity/activity_notifications_screen.dart';
import '../search/search_results_screen.dart';
import 'widgets/home_header.dart';
import 'widgets/recent_searches.dart';
import 'widgets/search_card.dart';

/// Ported from `HomeRootView` in `HomeViews.swift`.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isSearchRefreshing = false;

  Future<void> _presentSearchResults() async {
    if (_isSearchRefreshing) return;
    if (!ref.read(homeSearchProvider).canSearch) return;

    setState(() => _isSearchRefreshing = true);
    ref
        .read(selectedHomeSectionProvider.notifier)
        .select(HomeListingSection.rides);

    // Mirrors HomeRootView.presentSearchResults: refresh the marketplace
    // before showing results. Surface offline failures with a clear alert
    // instead of hanging on the spinner and then showing an empty list
    // (QA #59) — and cap the wait so a dead connection fails fast.
    try {
      await ref
          .read(marketplaceProvider.notifier)
          .refreshOrThrow()
          .timeout(const Duration(seconds: 15));
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSearchRefreshing = false);
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(tr('Нет доступа к интернету')),
          content: Text(
            isOfflineError(error)
                ? offlineMessage
                : tr('Не удалось загрузить поездки. Попробуйте ещё раз.'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(tr('Ок')),
            ),
          ],
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isSearchRefreshing = false);
    await Navigator.of(context).push(
      HSRoute<void>(builder: (_) => const SearchResultsScreen()),
    );
  }

  void _onSearchPressed() {
    final searchState = ref.read(homeSearchProvider);
    final historyItem = searchState.makeHistoryItem();
    if (historyItem != null) {
      ref.read(marketplaceProvider.notifier).recordSearch(historyItem);
    }
    _presentSearchResults();
  }

  Future<void> _onSelectRecent(LocationSearchHistoryItem item) async {
    HomeFlow.applySearchHistoryItem(item, ref);
    ref.read(marketplaceProvider.notifier).recordSearch(item);
    await _presentSearchResults();
  }

  @override
  Widget build(BuildContext context) {
    final recentSearches = ref
        .watch(marketplaceProvider)
        .searchHistory
        .take(3)
        .toList();
    final unread = ref.watch(activityProvider).unreadCount;

    return BackdropScaffoldBody(
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            HSSpacing.screen,
            HSSpacing.screen,
            HSSpacing.screen,
            HSSpacing.screen * 2,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(child: HomeHeader()),
                  const SizedBox(width: HSSpacing.inline),
                  ToolbarIconButton(
                    icon: Icons.notifications_none,
                    badgeText: unread > 0 ? '$unread' : null,
                    onTap: () => Navigator.of(context).push(
                      HSRoute<void>(
                        builder: (_) => const ActivityNotificationsScreen(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: HSSpacing.item),
              SearchCard(
                isLoading: _isSearchRefreshing,
                onSearch: _onSearchPressed,
              ),
              const SizedBox(height: HSSpacing.item),
              RecentSearchesSection(
                items: recentSearches,
                onSelect: _onSelectRecent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
