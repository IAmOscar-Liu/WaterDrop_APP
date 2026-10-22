import Flutter
import UIKit
import flutter_local_notifications


@main
@objc class AppDelegate: FlutterAppDelegate {
  private var badgeChannel: FlutterMethodChannel?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
      FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
        GeneratedPluginRegistrant.register(with: registry)
      }
      if #available(iOS 10.0, *) {
        UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
      }
      
      
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      badgeChannel = FlutterMethodChannel(name: "waterdrop/app_badge", binaryMessenger: controller.binaryMessenger)
      badgeChannel?.setMethodCallHandler { call, result in
        guard call.method == "setCount" else {
          result(FlutterMethodNotImplemented)
          return
        }
        guard let arguments = call.arguments as? [String: Any],
              let count = arguments["count"] as? Int, count >= 0 else {
          result(FlutterError(code: "invalid_count", message: "Badge count must be nonnegative", details: nil))
          return
        }
        if #available(iOS 16.0, *) {
          UNUserNotificationCenter.current().setBadgeCount(count) { error in
            DispatchQueue.main.async {
              if let error = error {
                result(FlutterError(code: "badge_failed", message: error.localizedDescription, details: nil))
              } else {
                result(nil)
              }
            }
          }
        } else {
          UIApplication.shared.applicationIconBadgeNumber = count
          result(nil)
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
