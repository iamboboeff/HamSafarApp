import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// Bridge to the iOS `AppDelegate` push setup, ported from `NotificationService`
/// + the APNs callbacks in `HamSafarApp.swift`. Wraps the
/// [MethodChannel] that delivers APNs device tokens from the native side.
///
/// Only iOS is wired up — Android/web are no-ops.
class PushNotificationsService {
  PushNotificationsService._() {
    if (Platform.isIOS) {
      _channel.setMethodCallHandler(_onMethodCall);
    }
  }

  /// Singleton, mirroring `NotificationService.shared` in Swift.
  static final PushNotificationsService instance =
      PushNotificationsService._();

  static const MethodChannel _channel = MethodChannel('hamsafar/push');

  final _tokenController = StreamController<String>.broadcast();
  String? _latestToken;

  /// Latest device token (hex). Null until APNs registers.
  String? get latestToken => _latestToken;

  /// Fires on each new device token from APNs.
  Stream<String> get tokenStream => _tokenController.stream;

  /// Requests notification permission (iOS only) and triggers APNs
  /// registration. Returns whether the user granted permission.
  Future<bool> requestPermissionAndRegister() async {
    if (!Platform.isIOS) return false;
    try {
      final granted =
          await _channel.invokeMethod<bool>('requestPermissionAndRegister');
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Pulls the cached device token from the native side, in case the APNs
  /// callback fired before the Dart listener attached.
  Future<String?> currentDeviceToken() async {
    if (!Platform.isIOS) return null;
    try {
      final token = await _channel.invokeMethod<String>('getDeviceToken');
      if (token != null) _latestToken = token;
      return token;
    } catch (_) {
      return null;
    }
  }

  Future<dynamic> _onMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onDeviceToken':
        final token = call.arguments;
        if (token is String && token.isNotEmpty) {
          _latestToken = token;
          _tokenController.add(token);
        }
        return null;
      case 'onRegistrationError':
        // Best-effort: surface via the stream's error channel for observers.
        _tokenController.addError(
          (call.arguments as String?) ?? 'unknown push error',
        );
        return null;
    }
    return null;
  }
}
