import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/trips_domain.dart';
import '../../state/app_state.dart';
import '../../theme/app_text.dart';
import '../../widgets/app_backdrop.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/ride_card.dart';
import '../ride_detail/ride_detail_screen.dart';

/// Ported from `MatchingDriversView` / `MatchingDriversForRequestView` in
/// `MyTripsViews.swift` — both showed the same "matching rides for a route"
/// list, so they collapse into one screen here.
class MatchingDriversScreen extends ConsumerWidget {
  const MatchingDriversScreen({
    super.key,
    required this.fromCity,
    required this.toCity,
    required this.minimumSeats,
  });

  final String fromCity;
  final String toCity;
  final int minimumSeats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final marketplace = ref.watch(marketplaceProvider);
    final bookedTrips = ref.watch(bookedTripsProvider);
    final isCurrentUser = ref.watch(isCurrentUserProvider);

    final matches = TripsDomain.matchingVisibleRides(
      rides: marketplace.rides,
      bookedTrips: bookedTrips,
      fromCity: fromCity,
      toCity: toCity,
      minimumSeats: minimumSeats,
      isCurrentUser: isCurrentUser,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Водители')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AppBackdrop(),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Подходящие водители', style: HSText.largeTitle),
                const SizedBox(height: 6),
                Text(
                  '$fromCity - $toCity',
                  style: HSText.subheadline.copyWith(
                    color: context.secondaryText,
                  ),
                ),
                const SizedBox(height: 18),
                if (matches.isEmpty)
                  GlassCard(
                    child: Text(
                      'По этому маршруту пока нет подходящих водителей.',
                      style: HSText.subheadline.copyWith(
                        color: context.secondaryText,
                      ),
                    ),
                  )
                else
                  for (final ride in matches) ...[
                    RideCard(
                      ride: ride,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => RideDetailScreen(ride: ride),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
