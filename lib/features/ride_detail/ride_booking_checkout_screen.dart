import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/l10n.dart';
import '../../core/supabase/supabase_service.dart';
import '../../domain/date_formatter.dart';
import '../../domain/ride_booking.dart';
import '../../models/app_tab.dart';
import '../../models/ride.dart';
import '../../models/trip_section.dart';
import '../../state/app_state.dart';
import '../../state/chat_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/buttons.dart';
import 'widgets/ride_detail_sections.dart';

/// Ported from `RideBookingCheckoutView` in `RideDetailViews.swift`.
///
/// Submits the booking through the real Supabase backend, then shows the
/// confirmation dialog and returns to the previous screen.
class RideBookingCheckoutScreen extends ConsumerStatefulWidget {
  const RideBookingCheckoutScreen({
    super.key,
    required this.ride,
    required this.passengerCount,
    required this.totalPriceText,
  });

  final Ride ride;
  final int passengerCount;
  final String totalPriceText;

  @override
  ConsumerState<RideBookingCheckoutScreen> createState() =>
      _RideBookingCheckoutScreenState();
}

class _RideBookingCheckoutScreenState
    extends ConsumerState<RideBookingCheckoutScreen> {
  final _messageController = TextEditingController();
  bool _isSubmitting = false;

  Ride get ride => widget.ride;
  bool get _instant => ride.instantBookingEnabled;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    String? errorMessage;
    try {
      await ref.read(supabaseServiceProvider).createBooking(
            ride: ride,
            seatsCount: widget.passengerCount,
          );
      ref.read(bookedTripsProvider.notifier).refresh();
    } on SupabaseServiceError catch (e) {
      errorMessage = e.message;
    } catch (_) {
      errorMessage =
          tr('Не удалось отправить бронирование. Попробуйте ещё раз.');
    }
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (errorMessage == null) {
      // First contextually-relevant moment for push: the passenger will want
      // to hear when the driver confirms. Prompts once; later calls no-op.
      ref.read(sessionProvider.notifier).ensurePushPermission();
      // Deliver the passenger's free-text message to the driver via chat
      // (QA #19). Best-effort; a chat hiccup must not fail the booking.
      final message = _messageController.text.trim();
      if (message.isNotEmpty) {
        await ref.read(chatProvider.notifier).sendBookingMessageToDriver(
              driver: ride.driver,
              route: '${ride.fromCity} - ${ride.toCity}',
              message: message,
              departureDate: ride.departureDate,
              rideId: ride.backendId,
            );
      }
      if (!mounted) return;
    }

    if (errorMessage != null) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(tr('Не удалось выполнить действие')),
          content: Text(errorMessage!),
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

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          _instant
              ? tr('Бронирование подтверждено')
              : tr('Заявка отправлена'),
        ),
        content: Text(
          _instant
              ? tr('Место закреплено сразу, поездка уже появилась в ваших '
                  'активных поездках.')
              : tr('Водитель получит вашу заявку и сможет подтвердить её.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(tr('Ок')),
          ),
        ],
      ),
    );
    if (!mounted) return;
    // Take the rider to My Trips to track the booking — «Запросы» for a pending
    // заявка, «Активные» for an instant confirmation — unwinding the
    // search → detail → checkout stack back to the tab shell.
    ref.read(requestedTripsSectionProvider.notifier).request(
          _instant ? TripSection.active : TripSection.requests,
        );
    ref.read(selectedTabProvider.notifier).select(AppTab.trips);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    final arrivalTimeText = RideBookingDomain.arrivalTimeText(ride);
    final seatWord =
        widget.passengerCount == 1 ? tr('место') : tr('места');

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(),
      // Tap anywhere outside the message field to dismiss the keyboard — the
      // multiline field never submits on return, so users need this to get the
      // keyboard out of the way.
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Stack(
        fit: StackFit.expand,
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('Проверьте данные вашего бронирования'),
                  style: HSText.largeTitle,
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 26,
                      child: Icon(
                        _instant ? Icons.bolt : Icons.event_available,
                        size: 18,
                        color: hs.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _instant
                                ? tr('Ваше бронирование подтвердится сразу')
                                : tr('Ваше бронирование будет подтверждено только '
                                    'после одобрения водителя'),
                            style: HSText.subheadlineSemibold,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _instant
                                ? tr('Место закрепится без дополнительного '
                                    'ожидания.')
                                : tr('После отправки водитель увидит ваш запрос и '
                                    'сможет подтвердить поездку.'),
                            style: HSText.footnote.copyWith(
                              color: context.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Divider(color: hs.stroke),
                const SizedBox(height: 18),
                Text(
                  DateTextFormatter.weekdayDayMonth(ride.departureDate),
                  style: HSText.title3,
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateTextFormatter.time(ride.departureDate),
                          style: HSText.headline,
                        ),
                        const SizedBox(height: 26),
                        Text(arrivalTimeText, style: HSText.headline),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        children: [
                          RideLocationRow(
                            title: ride.fromCity,
                            subtitle:
                                ride.meetingPoint.addressLine ??
                                tr('Уточняется'),
                            accent: hs.primary,
                            showsConnector: true,
                          ),
                          RideLocationRow(
                            title: ride.toCity,
                            subtitle:
                                ride.destinationPoint.addressLine ??
                                tr('Уточняется'),
                            accent: hs.passenger,
                            showsConnector: false,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Divider(color: hs.stroke),
                const SizedBox(height: 18),
                Text(tr('Всего к оплате'), style: HSText.title3),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trf('{count} {seatWord}: {price}', {
                            'count': '${widget.passengerCount}',
                            'seatWord': seatWord,
                            'price': widget.totalPriceText,
                          }),
                          style: HSText.title3,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tr('Во время поездки'),
                          style: HSText.subheadline.copyWith(
                            color: context.secondaryText,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(tr('Наличными'), style: HSText.title3),
                  ],
                ),
                const SizedBox(height: 18),
                Divider(color: hs.stroke),
                const SizedBox(height: 18),
                Text(
                  trf(
                    'Напишите пользователю {name}, чтобы повысить '
                    'свои шансы на совместную поездку',
                    {'name': ride.driver.name},
                  ),
                  style: HSText.title3,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _messageController,
                  minLines: 5,
                  maxLines: 8,
                  decoration: InputDecoration(
                    hintText: tr('Введите текст'),
                    filled: true,
                    fillColor: hs.secondarySurface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: hs.stroke),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: hs.stroke),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        ),
      ),
      bottomNavigationBar: Container(
        color: hs.cardBackground,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Divider(height: 1, color: hs.stroke),
            Padding(
              // Add the keyboard inset so the action button rises above the
              // keyboard instead of being hidden behind it (bottomNavigationBar
              // is otherwise pinned to the physical bottom of the screen).
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                12 +
                    MediaQuery.of(context).viewInsets.bottom +
                    MediaQuery.of(context).padding.bottom,
              ),
              child: PrimaryFilledButton(
                label: _instant
                    ? tr('Забронировать сразу')
                    : tr('Отправить запрос'),
                isLoading: _isSubmitting,
                onPressed: _isSubmitting ? null : _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
