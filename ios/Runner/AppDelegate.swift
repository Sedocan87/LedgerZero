import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var platformChannel: PlatformInfoChannel?
  private let privacyCover = PrivacyCover()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    privacyCover.observeSceneLifecycle()
    // flutter_local_notifications: foreground presentation and tap callbacks.
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "LedgerZeroNative") {
      platformChannel = PlatformInfoChannel(messenger: registrar.messenger())
    }
  }
}

/// Covers every window of a scene while it is not active, so the app
/// switcher snapshot never shows financial data (the UIScene lifecycle is
/// used, so this listens to scene notifications rather than app ones).
final class PrivacyCover {
  private static let coverTag = 0x4C5A_5052

  func observeSceneLifecycle() {
    let center = NotificationCenter.default
    center.addObserver(
      forName: UIScene.willDeactivateNotification, object: nil, queue: .main
    ) { [weak self] note in
      self?.cover(note.object as? UIWindowScene)
    }
    center.addObserver(
      forName: UIScene.didEnterBackgroundNotification, object: nil, queue: .main
    ) { [weak self] note in
      self?.cover(note.object as? UIWindowScene)
    }
    center.addObserver(
      forName: UIScene.didActivateNotification, object: nil, queue: .main
    ) { [weak self] note in
      self?.uncover(note.object as? UIWindowScene)
    }
  }

  private func cover(_ scene: UIWindowScene?) {
    guard let scene = scene else { return }
    for window in scene.windows where window.viewWithTag(Self.coverTag) == nil {
      let view = UIView(frame: window.bounds)
      view.tag = Self.coverTag
      view.backgroundColor = .systemBackground
      view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      let icon = UIImageView(image: UIImage(systemName: "lock.fill"))
      icon.tintColor = .secondaryLabel
      icon.translatesAutoresizingMaskIntoConstraints = false
      view.addSubview(icon)
      NSLayoutConstraint.activate([
        icon.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        icon.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        icon.widthAnchor.constraint(equalToConstant: 48),
        icon.heightAnchor.constraint(equalToConstant: 48),
      ])
      window.addSubview(view)
    }
  }

  private func uncover(_ scene: UIWindowScene?) {
    guard let scene = scene else { return }
    for window in scene.windows {
      window.viewWithTag(Self.coverTag)?.removeFromSuperview()
    }
  }
}

/// Build-time configuration the Dart side needs to know about.
final class PlatformInfoChannel {
  private let channel: FlutterMethodChannel

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "com.ledgerzero.app/platform", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "googleSignInConfigured":
        // GIDClientID comes from GOOGLE_IOS_CLIENT_ID in
        // ios/Flutter/GoogleSignIn.xcconfig (see docs/GOOGLE_DRIVE_SETUP.md).
        let clientId = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String
        result(clientId.map { !$0.isEmpty && $0.hasSuffix(".apps.googleusercontent.com") } ?? false)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
