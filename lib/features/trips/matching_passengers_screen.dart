import 'package:flutter/material.dart';

import '../../models/booked_trip.dart';
import '../../theme/app_text.dart';
import '../../widgets/app_backdrop.dart';
import '../../widgets/glass_card.dart';

/// Ported from `MatchingPassengersForRideView` in `MyTripsViews.swift`.
///
/// The incoming-booking list is backed by `SupabaseService` in the Swift app;
/// until that backend layer is ported there are no bookings to show, so the
/// screen renders its empty state.
class MatchingPassengersScreen extends StatelessWidget {
  const MatchingPassengersScreen({super.key, required this.trip});

  final BookedTrip trip;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Заявки')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AppBackdrop(),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Входящие заявки', style: HSText.largeTitle),
                const SizedBox(height: 6),
                Text(
                  '${trip.ride.fromCity} - ${trip.ride.toCity}',
                  style: HSText.subheadline.copyWith(
                    color: context.secondaryText,
                  ),
                ),
                const SizedBox(height: 18),
                GlassCard(
                  child: Text(
                    'Пока нет новых заявок на эту поездку.',
                    style: HSText.subheadline.copyWith(
                      color: context.secondaryText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
