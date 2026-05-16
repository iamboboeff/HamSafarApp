import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/date_formatter.dart';
import '../../models/ride.dart';
import '../../models/user_profile.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../../widgets/app_backdrop.dart';
import '../../widgets/glass_card.dart';
import 'report_user_screen.dart';
import 'widgets/profile_widgets.dart';

/// Ported from `UserPublicProfileView` in `ProfileViews.swift` — shown when
/// tapping a driver/passenger avatar or name on a ride or request card.
/// Loads the profile, public stats and review history in parallel.
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

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Профиль пользователя'),
        actions: [
          IconButton(
            tooltip: 'Пожаловаться',
            icon: const Icon(Icons.flag_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ReportUserScreen(reportedUser: _profile),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AppBackdrop(),
          RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                _HeaderCard(profile: _profile),
                const SizedBox(height: HSSpacing.item),
                _StatsCard(stats: _stats, isLoading: _isLoading),
                const SizedBox(height: HSSpacing.item),
                _ReviewsSection(
                  reviews: _reviews,
                  isLoading: _isLoading,
                  hs: hs,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.profile});
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    return GlassCard(
      child: Column(
        children: [
          ProfileAvatarView(
            initials: profile.initials,
            avatarBytes: profile.avatarBytes,
            size: 88,
          ),
          const SizedBox(height: 12),
          Text(profile.name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.star, color: hs.warm, size: 14),
              const SizedBox(width: 6),
              Text(profile.ratingText,
                  style: HSText.subheadlineSemibold),
              const SizedBox(width: 8),
              Text('•',
                  style:
                      HSText.subheadline.copyWith(color: context.secondaryText)),
              const SizedBox(width: 8),
              Text('${profile.completedTrips} поездок',
                  style: HSText.subheadline
                      .copyWith(color: context.secondaryText)),
            ],
          ),
          const SizedBox(height: 4),
          Text(profile.identityLine,
              style:
                  HSText.caption.copyWith(color: context.secondaryText)),
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
              label: 'Поездок как водитель',
              value: isLoading ? '—' : '${stats.driverTripsCount}',
            ),
          ),
          Container(width: 1, height: 36, color: context.hs.stroke),
          Expanded(
            child: _Stat(
              label: 'Поездок как пассажир',
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
        Text(label,
            textAlign: TextAlign.center,
            style:
                HSText.caption.copyWith(color: context.secondaryText)),
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
          child: Text('Отзывы', style: HSText.headline),
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
                  'Пока нет отзывов о пользователе.',
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
              Text(review.rating.toStringAsFixed(1),
                  style: HSText.subheadlineSemibold),
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
