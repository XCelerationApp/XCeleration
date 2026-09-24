import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      // Keeps the screen on while a race runs, so the Timer or Bib Recorder
      // never has to unlock the phone between runners.
      FlutterMethodChannel(
        name: "xceleration/screen_awake",
        binaryMessenger: controller.binaryMessenger
      ).setMethodCallHandler { call, result in
        guard call.method == "setAwake", let on = call.arguments as? Bool else {
          result(FlutterMethodNotImplemented)
          return
        }
        UIApplication.shared.isIdleTimerDisabled = on
        result(nil)
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
