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
}
