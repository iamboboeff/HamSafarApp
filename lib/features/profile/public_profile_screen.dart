import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hamsafar/core/i18n/l10n.dart';
import '../../domain/date_formatter.dart';
import '../../models/ride.dart';
import '../../models/user_profile.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../../widgets/common.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/hs_route.dart';
import '../ride_detail/ride_detail_screen.dart';
import 'report_user_screen.dart';
import 'widgets/profile_widgets.dart';

/// Ported from `UserPublicProfileView` in `ProfileViews.swift` — shown when
/// tapping a driver/passenger avatar or name on a ride or request card.
/// Loads the profile, public stats, active rides and review history in parallel.
class UserPublicProfileScreen extends ConsumerStatefulWidget {
  const UserPublicProfileScreen({
    super.key,
    required this.userId,
    required this.fallback,
  });

  /// Backend uuid of the profile to load.
  final String userId;

  /// Cached profile already in hand (from the ride/request card) — shown
  /// while the network fetch is in flight.
  final UserProfile fallback;

  @override
  ConsumerState<UserPublicProfileScreen> createState() =>
      _UserPublicProfileScreenState();
}

class _UserPublicProfileScreenState
    extends ConsumerState<UserPublicProfileScreen> {
  late UserProfile _profile;
  PublicProfileStats _stats = PublicProfileStats.empty;
  List<RideReview> _reviews = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _profile = widget.fallback;
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final service = ref.read(supabaseServiceProvider);
    final results = await Future.wait([
      service.fetchPublicProfile(widget.userId),
      service.fetchPublicProfileStats(widget.userId),
      service.fetchProfileReviews(widget.userId),
    ]);
    if (!mounted) return;
    setState(() {
      final fetched = results[0] as UserProfile?;
      if (fetched != null) _profile = fetched;
      _stats = results[1] as PublicProfileStats;
      _reviews = results[2] as List<RideReview>;
      _isLoading = false;
    });
  }

  /// Mirrors `UserPublicProfileView.activeRides` — driver-side future rides
  /// in the live marketplace, sorted by departure.
  List<Ride> _activeRidesFor(String backendId, List<Ride> rides) {
    final now = DateTime.now();
    final filtered = rides
        .where(
          (ride) =>
              ride.driver.backendId == backendId &&
              ride.departureDate.isAfter(now),
        )
        .toList();
    filtered.sort((a, b) => a.departureDate.compareTo(b.departureDate));
    return filtered;
  }

  /// Blocks or unblocks this user (App Store Guideline 1.2). Blocking hides
  /// their content both ways and pops back; unblocking restores it.
  Future<void> _toggleBlock(bool isBlocked) async {
    final id = _profile.backendId;
    if (id == null) return;
    final notifier = ref.read(blockedUserIdsProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);

    if (isBlocked) {
      try {
        await notifier.unblock(id);
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(content: Text(tr('Пользователь разблокирован.'))),
        );
      } catch (_) {
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text(tr('Не удалось разблокировать. Попробуйте ещё раз.')),
          ),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('Заблокировать пользователя?')),
        content: Text(
          trf(
            'Вы больше не увидите поездки, запросы и сообщения от {name}, '
            'а этот пользователь — ваши. Разблокировать можно '
            'в настройках приватности.',
            {'name': _profile.name},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(tr('Отмена')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(tr('Заблокировать')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await notifier.block(id);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(tr('Пользователь заблокирован.'))),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(tr('Не удалось заблокировать. Попробуйте ещё раз.')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    final rides = ref.watch(marketplaceProvider).rides;
    final activeRides = _profile.backendId == null
        ? const <Ride>[]
        : _activeRidesFor(_profile.backendId!, rides);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(tr('Профиль пользователя')),
        actions: [
          Builder(
            builder: (context) {
              final id = _profile.backendId;
              final isBlocked =
                  id != null && ref.watch(blockedUserIdsProvider).contains(id);
              return PopupMenuButton<String>(
                tooltip: tr('Ещё'),
                icon: const Icon(Icons.more_horiz),
                onSelected: (value) {
                  if (value == 'report') {
                    Navigator.of(context).push(
                      HSRoute<void>(
                        builder: (_) =>
                            ReportUserScreen(reportedUser: _profile),
                      ),
                    );
                  } else if (value == 'block') {
                    _toggleBlock(isBlocked);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'report',
                    child: Text(tr('Пожаловаться')),
                  ),
                  PopupMenuItem(
                    value: 'block',
                    child: Text(
                      isBlocked ? tr('Разблокировать') : tr('Заблокировать'),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            _load(),
            ref.read(marketplaceProvider.notifier).refresh(),
          ]);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            _HeaderCard(
              profile: _profile,
              stats: _stats,
              isLoading: _isLoading,
            ),
            const SizedBox(height: HSSpacing.item),
            _StatsCard(stats: _stats, isLoading: _isLoading),
            const SizedBox(height: HSSpacing.item),
            _ActiveRidesSection(
              rides: activeRides,
              hs: hs,
            ),
            const SizedBox(height: HSSpacing.item),
            _ReviewsSection(
              reviews: _reviews,
              isLoading: _isLoading,
              hs: hs,
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.profile,
    required this.stats,
    required this.isLoading,
  });
  final UserProfile profile;
  final PublicProfileStats stats;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    return GlassCard(
      child: Column(
        children: [
          heroAvatar(
            id: profile.backendId,
            child: ProfileAvatarView(
              initials: profile.initials,
              avatarBytes: profile.avatarBytes,
              avatarUrl: profile.avatarUrl,
              size: 88,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            profile.name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              // Rating pill only once the user actually has reviews — no
              // "★ —" placeholder for new users.
              if (profile.hasRating)
                _HeaderPill(
                  icon: Icons.star_rounded,
                  iconColor: hs.warm,
                  label: profile.ratingText,
                ),
              _HeaderPill(
                icon: Icons.route_rounded,
                iconColor: hs.primary,
                // Use the same authoritative counter as the stats card so the
                // header doesn't disagree with the breakdown below (QA #21).
                label: trf('{count} поездок', {
                  'count':
                      '${isLoading ? profile.completedTrips : stats.totalTrips}',
                }),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            profile.identityLine,
            textAlign: TextAlign.center,
            style: HSText.caption.copyWith(color: context.secondaryText),
          ),
        ],
      ),
    );
  }
}

class _HeaderPill extends StatelessWidget {
  const _HeaderPill({
    required this.icon,
    required this.iconColor,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: hs.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: hs.stroke),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 6),
          Text(label, style: HSText.captionSemibold),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats, required this.isLoading});
  final PublicProfileStats stats;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        children: [
          Expanded(
            child: _Stat(
              label: tr('Поездок как водитель'),
              value: isLoading ? '—' : '${stats.driverTripsCount}',
            ),
          ),
          Container(width: 1, height: 36, color: context.hs.stroke),
          Expanded(
            child: _Stat(
              label: tr('Поездок как пассажир'),
              value: isLoading ? '—' : '${stats.passengerTripsCount}',
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(value, style: HSText.title3),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: HSText.caption.copyWith(color: context.secondaryText),
        ),
      ],
    );
  }
}

/// Ported from the `"Активные поездки"` section in `UserPublicProfileView`.
class _ActiveRidesSection extends StatelessWidget {
  const _ActiveRidesSection({required this.rides, required this.hs});

  final List<Ride> rides;
  final AppColors hs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Text(tr('Активные поездки'), style: HSText.headline),
              if (rides.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: hs.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${rides.length}',
                    style: HSText.captionSemibold.copyWith(color: hs.primary),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (rides.isEmpty)
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  tr('Сейчас активных поездок нет.'),
                  style:
                      HSText.subheadline.copyWith(color: context.secondaryText),
                ),
              ),
            ),
          )
        else
          GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 14),
            child: Column(
              children: [
                for (var i = 0; i < rides.length; i++) ...[
                  _ActiveRideRow(ride: rides[i], hs: hs),
                  if (i != rides.length - 1)
                    Divider(height: 1, color: hs.stroke),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _ActiveRideRow extends StatelessWidget {
  const _ActiveRideRow({required this.ride, required this.hs});
  final Ride ride;
  final AppColors hs;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.of(context).push(
        HSRoute<void>(builder: (_) => RideDetailScreen(ride: ride)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RouteTimelineGlyph(hs: hs),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${ride.fromCity} → ${ride.toCity}',
                    style: HSText.subheadlineSemibold,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 10,
                    runSpacing: 2,
                    children: [
                      _MetaItem(
                        icon: Icons.calendar_today_rounded,
                        label: DateTextFormatter.dayMonthYear(
                          ride.departureDate,
                        ),
                      ),
                      _MetaItem(
                        icon: Icons.access_time_rounded,
                        label: DateTextFormatter.time(ride.departureDate),
                      ),
                      _MetaItem(
                        icon: Icons.payments_outlined,
                        label: ride.formattedPrice(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                Icons.chevron_right_rounded,
                color: context.secondaryText,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteTimelineGlyph extends StatelessWidget {
  const _RouteTimelineGlyph({required this.hs});
  final AppColors hs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: hs.primary,
              shape: BoxShape.circle,
            ),
          ),
          Container(width: 2, height: 22, color: hs.stroke),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: hs.passenger,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: context.secondaryText),
        const SizedBox(width: 4),
        Text(
          label,
          style: HSText.caption.copyWith(color: context.secondaryText),
        ),
      ],
    );
  }
}

class _ReviewsSection extends StatelessWidget {
  const _ReviewsSection({
    required this.reviews,
    required this.isLoading,
    required this.hs,
  });

  final List<RideReview> reviews;
  final bool isLoading;
  final AppColors hs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(tr('Отзывы'), style: HSText.headline),
        ),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (reviews.isEmpty)
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  tr('Пока нет отзывов о пользователе.'),
                  style: HSText.subheadline
                      .copyWith(color: context.secondaryText),
                ),
              ),
            ),
          )
        else
          for (final review in reviews)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ReviewRow(review: review, hs: hs),
            ),
      ],
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.review, required this.hs});
  final RideReview review;
  final AppColors hs;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(review.author, style: HSText.subheadlineSemibold),
              ),
              const SizedBox(width: 8),
              Icon(Icons.star, size: 14, color: hs.warm),
              const SizedBox(width: 4),
              Text(
                review.rating.toStringAsFixed(1),
                style: HSText.subheadlineSemibold,
              ),
              if (review.createdAt != null) ...[
                const SizedBox(width: 8),
                Text(
                  DateTextFormatter.dayMonthShort(review.createdAt!),
                  style:
                      HSText.caption.copyWith(color: context.secondaryText),
                ),
              ],
            ],
          ),
          if (review.comment.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(review.comment, style: HSText.subheadline),
          ],
        ],
      ),
    );
  }
}
