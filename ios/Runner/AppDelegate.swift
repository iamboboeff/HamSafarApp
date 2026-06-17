import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

  /// Channel name shared with the Dart `PushNotificationsService`.
  private static let pushChannelName = "hamsafar/push"

  /// Method channel used to push token + permission events to Dart. Set when
  /// the first Flutter engine registers via `didInitializeImplicitFlutterEngine`.
  private var pushChannel: FlutterMethodChannel?

  /// Cached APNs token bytes encoded as hex. Held until the Dart side
  /// initialises and asks for it via `getDeviceToken`.
  private var pendingDeviceToken: String?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let messenger = engineBridge.applicationRegistrar.messenger()
    let channel = FlutterMethodChannel(
      name: Self.pushChannelName,
      binaryMessenger: messenger
    )
    pushChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call: call, result: result)
    }
  }

  // MARK: - MethodChannel handler

  private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "requestPermissionAndRegister":
      UNUserNotificationCenter.current().requestAuthorization(
        options: [.alert, .badge, .sound]
      ) { granted, _ in
        DispatchQueue.main.async {
          if granted {
            UIApplication.shared.registerForRemoteNotifications()
          }
          result(granted)
        }
      }
    case "registerIfAuthorized":
      // Re-register with APNs without ever showing the permission prompt —
      // used on app launch for users who already granted notifications, so
      // the system prompt is reserved for the first contextually-relevant
      // action (publishing a ride / sending a booking request).
      UNUserNotificationCenter.current().getNotificationSettings { settings in
        DispatchQueue.main.async {
          let authorized = settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
          if authorized {
            UIApplication.shared.registerForRemoteNotifications()
          }
          result(authorized)
        }
      }
    case "getDeviceToken":
      result(pendingDeviceToken)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - APNs registration callbacks

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
    pendingDeviceToken = hex
    pushChannel?.invokeMethod("onDeviceToken", arguments: hex)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    pushChannel?.invokeMethod(
      "onRegistrationError",
      arguments: error.localizedDescription
    )
  }

  // MARK: - Foreground presentation
  //
  // Without this delegate method, iOS swallows incoming push notifications
  // when the app is in foreground — APNs delivers the payload, but no banner,
  // sound or badge is shown. Forwarding `.banner, .sound, .badge` makes the
  // system render the notification UI even while the user is inside the app.

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    // Tell Dart a push arrived while in foreground so it can refresh the
    // in-app notification feed / counter (QA #23).
    pushChannel?.invokeMethod("onPushReceived", arguments: nil)
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .list, .sound, .badge])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    // The user tapped a notification — forward its payload to Dart so it can
    // navigate to the relevant chat/notification screen (QA #25).
    let userInfo = response.notification.request.content.userInfo
    var payload = [String: Any]()
    for (key, value) in userInfo {
      if let key = key as? String { payload[key] = value }
    }
    pushChannel?.invokeMethod("onPushOpened", arguments: payload)
    completionHandler()
  }
}
