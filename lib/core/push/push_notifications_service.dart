import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Cross-platform bridge to the device-token side of push.
///
/// - **iOS:** talks to `AppDelegate.swift` over the `hamsafar/push`
///   [MethodChannel]. APNs hex token comes back via `onDeviceToken`.
/// - **Android:** talks to Firebase Cloud Messaging through the
///   `firebase_messaging` plugin. FCM token comes back from `getToken()`
///   on init and from `onTokenRefresh` whenever Google rotates it.
///
/// Both surfaces feed into the same [tokenStream], so the call sites in
/// `SessionNotifier` are platform-agnostic — they just listen for tokens
/// and forward them to Supabase via `registerPushDeviceToken`.
class PushNotificationsService {
  PushNotificationsService._() {
    if (Platform.isIOS) {
      _channel.setMethodCallHandler(_onIOSMethodCall);
    } else if (Platform.isAndroid) {
      _messaging = FirebaseMessaging.instance;
      // FCM tokens are rotated by Google periodically (app reinstall,
      // GCM unregister, instance ID quota). Treat each rotation as a fresh
      // token — the upsert in Supabase is idempotent on `(user_id, token)`.
      _tokenRefreshSub = _messaging!.onTokenRefresh.listen((token) {
        if (token.isEmpty) return;
        _latestToken = token;
        _tokenController.add(token);
      });
      // Set up a local-notification channel so foreground FCM messages are
      // actually shown in the tray on Android (the OS does NOT auto-display
      // them while the app is in use) (QA #86).
      unawaited(_initAndroidLocalNotifications());
      // Foreground pushes (Android delivers these to the app, not the tray):
      // refresh the in-app feed AND surface a tray notification (QA #23, #86).
      _foregroundMessageSub = FirebaseMessaging.onMessage.listen((message) {
        _messageController.add(null);
        _showLocalNotification(message);
      });
      // Taps that reopen the app from a notification — refresh, and carry the
      // payload so the app can navigate to the relevant screen (QA #25).
      _openedAppSub = FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _messageController.add(null);
        _openedController.add(_dataOf(message));
      });
    }
  }

  /// Singleton, mirroring `NotificationService.shared` in Swift.
  static final PushNotificationsService instance =
      PushNotificationsService._();

  /// Method channel shared with `AppDelegate.swift` (iOS only).
  static const MethodChannel _channel = MethodChannel('hamsafar/push');

  /// Lazy-resolved FCM client on Android; null on iOS/web.
  FirebaseMessaging? _messaging;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundMessageSub;
  StreamSubscription<RemoteMessage>? _openedAppSub;

  final _tokenController = StreamController<String>.broadcast();
  final _messageController = StreamController<void>.broadcast();
  final _openedController = StreamController<Map<String, dynamic>>.broadcast();
  String? _latestToken;

  /// Android local-notification plugin, used to render foreground FCM messages
  /// in the system tray (QA #86). Null until [_initAndroidLocalNotifications].
  FlutterLocalNotificationsPlugin? _localNotifications;

  static const _androidChannel = AndroidNotificationChannel(
    'hamsafar_messages',
    'Уведомления',
    description: 'Сообщения и события по поездкам',
    importance: Importance.high,
  );

  /// Latest device token (APNs hex on iOS, FCM string on Android).
  /// Null until the platform reports one.
  String? get latestToken => _latestToken;

  /// Fires on each new device token from the platform.
  Stream<String> get tokenStream => _tokenController.stream;

  /// Fires when a push is received in the foreground (or taps that reopen the
  /// app), so listeners can refresh the in-app notification feed / counter.
  Stream<void> get incomingMessages => _messageController.stream;

  /// Fires when the user *taps* a notification, carrying the push payload so the
  /// app can navigate to the relevant chat/notification screen (QA #25).
  Stream<Map<String, dynamic>> get openedMessages => _openedController.stream;

  /// Handles a notification tap that cold-started the app from a terminated
  /// state (Android). Call once after startup so that path also navigates.
  Future<void> processInitialMessage() async {
    final messaging = _messaging;
    if (messaging == null) return;
    final initial = await messaging.getInitialMessage();
    if (initial != null) _openedController.add(_dataOf(initial));
  }

  Map<String, dynamic> _dataOf(RemoteMessage message) =>
      Map<String, dynamic>.from(message.data);

  Future<void> _initAndroidLocalNotifications() async {
    final plugin = FlutterLocalNotificationsPlugin();
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final data = jsonDecode(payload);
          if (data is Map) {
            _openedController.add(Map<String, dynamic>.from(data));
          }
        } catch (_) {
          // Malformed payload — nothing to route to.
        }
      },
    );
    await plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);
    _localNotifications = plugin;
  }

  void _showLocalNotification(RemoteMessage message) {
    final plugin = _localNotifications;
    final notification = message.notification;
    // Only data-with-notification messages are surfaced; pure-data pushes that
    // just trigger a refresh stay silent.
    if (plugin == null || notification == null) return;
    plugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  /// Requests notification permission and triggers token registration.
  ///
  /// - iOS: opens the system prompt via `UNUserNotificationCenter` and
  ///   then asks UIKit to register with APNs.
  /// - Android 13+: opens the `POST_NOTIFICATIONS` runtime prompt via
  ///   `FirebaseMessaging.requestPermission`. On older Android the call
  ///   returns `authorized` without showing any UI.
  Future<bool> requestPermissionAndRegister() async {
    if (Platform.isIOS) {
      try {
        final granted =
            await _channel.invokeMethod<bool>('requestPermissionAndRegister');
        return granted ?? false;
      } catch (_) {
        return false;
      }
    }
    if (Platform.isAndroid) {
      final messaging = _messaging;
      if (messaging == null) return false;
      try {
        final settings = await messaging.requestPermission();
        final granted = settings.authorizationStatus ==
                AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
        if (granted) {
          // Fetch the token immediately so the first listener call doesn't
          // have to wait for an `onTokenRefresh` event (which only fires
          // when Google rotates it).
          unawaited(_emitInitialAndroidToken());
        }
        return granted;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  /// Registers for push **without** ever showing a permission prompt, but
  /// only if the user has already granted notifications. Used on app launch
  /// so returning users keep getting tokens, while the system prompt stays
  /// reserved for the first contextually-relevant action.
  Future<bool> registerIfAlreadyGranted() async {
    if (Platform.isIOS) {
      try {
        final granted =
            await _channel.invokeMethod<bool>('registerIfAuthorized');
        return granted ?? false;
      } catch (_) {
        return false;
      }
    }
    if (Platform.isAndroid) {
      final messaging = _messaging;
      if (messaging == null) return false;
      try {
        // `getNotificationSettings` reads the current status without prompting.
        final settings = await messaging.getNotificationSettings();
        final granted = settings.authorizationStatus ==
                AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
        if (granted) {
          unawaited(_emitInitialAndroidToken());
        }
        return granted;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  /// Returns the current device token, asking the platform if we haven't
  /// cached one yet. Mirrors `latestToken` semantics but always hits the
  /// native side once.
  Future<String?> currentDeviceToken() async {
    if (Platform.isIOS) {
      try {
        final token = await _channel.invokeMethod<String>('getDeviceToken');
        if (token != null) _latestToken = token;
        return token;
      } catch (_) {
        return null;
      }
    }
    if (Platform.isAndroid) {
      final messaging = _messaging;
      if (messaging == null) return null;
      try {
        final token = await messaging.getToken();
        if (token != null && token.isNotEmpty) _latestToken = token;
        return token;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<void> _emitInitialAndroidToken() async {
    final token = await currentDeviceToken();
    if (token != null && token.isNotEmpty) {
      _tokenController.add(token);
    }
  }

  Future<dynamic> _onIOSMethodCall(MethodCall call) async {
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
      case 'onPushReceived':
        // Forwarded by AppDelegate when a push is presented in the foreground
        // (iOS). Mirrors the Android `onMessage` path so the in-app feed
        // refreshes (QA #23).
        _messageController.add(null);
        return null;
      case 'onPushOpened':
        // Forwarded by AppDelegate when the user taps a notification (iOS), so
        // the app can navigate to the relevant screen (QA #25).
        _messageController.add(null);
        final args = call.arguments;
        _openedController.add(
          args is Map ? Map<String, dynamic>.from(args) : <String, dynamic>{},
        );
        return null;
    }
    return null;
  }

  /// Tear-down hook for tests / hot restart paths.
  Future<void> dispose() async {
    await _tokenRefreshSub?.cancel();
    await _foregroundMessageSub?.cancel();
    await _openedAppSub?.cancel();
    await _tokenController.close();
    await _messageController.close();
    await _openedController.close();
  }
}
