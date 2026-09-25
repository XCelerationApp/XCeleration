import AVFoundation
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
      // Voice entry: lets haptics through while the microphone records (iOS
      // mutes them otherwise), and asks for the microphone up front so a
      // refusal can be explained rather than heard as silence.
      FlutterMethodChannel(
        name: "xceleration/audio_session",
        binaryMessenger: controller.binaryMessenger
      ).setMethodCallHandler { call, result in
        let session = AVAudioSession.sharedInstance()
        switch call.method {
        case "allowHapticsWhileRecording":
          if #available(iOS 13.0, *) {
            try? session.setAllowHapticsAndSystemSoundsDuringRecording(true)
          }
          result(nil)
        case "requestMicPermission":
          switch session.recordPermission {
          case .granted:
            result(true)
          case .denied:
            result(false)
          default:
            session.requestRecordPermission { granted in
              DispatchQueue.main.async { result(granted) }
            }
          }
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
