import Flutter
import LocalAuthentication
import Security
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var biometricKeyChannel: BiometricKeyChannel?
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
      biometricKeyChannel = BiometricKeyChannel(messenger: registrar.messenger())
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

/// Keychain storage for the database key that requires Face ID / Touch ID
/// on every read: access control `.biometryCurrentSet` (a changed
/// enrolment makes the item unreadable) and
/// `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly` (never leaves the
/// device, removed if the passcode is turned off).
final class BiometricKeyChannel {
  private static let service = "com.ledgerzero.app.biometric"
  private static let account = "wrapped_dek"
  private let channel: FlutterMethodChannel

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "com.ledgerzero.app/biometric_key", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "isAvailable":
      result(Self.biometricsAvailable())
    case "hasKey":
      result(Self.hasKey())
    case "store":
      guard let secret = (args["secret"] as? FlutterStandardTypedData)?.data else {
        result(FlutterError(code: "failed", message: "missing secret", details: nil))
        return
      }
      store(secret, reason: (args["subtitle"] as? String) ?? "LedgerZero", result: result)
    case "read":
      read(
        reason: (args["subtitle"] as? String) ?? "LedgerZero",
        cancel: args["cancel"] as? String, result: result)
    case "delete":
      Self.delete()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private static func baseQuery() -> [CFString: Any] {
    return [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: service,
      kSecAttrAccount: account,
    ]
  }

  private static func biometricsAvailable() -> Bool {
    var error: NSError?
    return LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
  }

  private static func hasKey() -> Bool {
    let context = LAContext()
    context.interactionNotAllowed = true
    var query = baseQuery()
    query[kSecUseAuthenticationContext] = context
    query[kSecMatchLimit] = kSecMatchLimitOne
    let status = SecItemCopyMatching(query as CFDictionary, nil)
    return status == errSecSuccess || status == errSecInteractionNotAllowed
  }

  private static func delete() {
    SecItemDelete(baseQuery() as CFDictionary)
  }

  private func store(_ secret: Data, reason: String, result: @escaping FlutterResult) {
    guard Self.biometricsAvailable() else {
      result(FlutterError(code: "unavailable", message: nil, details: nil))
      return
    }
    // Adding needs no authentication; confirm the user is present first.
    LAContext().evaluatePolicy(
      .deviceOwnerAuthenticationWithBiometrics, localizedReason: reason
    ) { success, error in
      DispatchQueue.main.async {
        guard success else {
          result(Self.flutterError(for: error))
          return
        }
        var acError: Unmanaged<CFError>?
        guard
          let access = SecAccessControlCreateWithFlags(
            nil, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, .biometryCurrentSet, &acError)
        else {
          result(FlutterError(code: "unavailable", message: nil, details: nil))
          return
        }
        Self.delete()
        var query = Self.baseQuery()
        query[kSecAttrAccessControl] = access
        query[kSecValueData] = secret
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecSuccess {
          result(nil)
        } else {
          result(FlutterError(code: "failed", message: "keychain \(status)", details: nil))
        }
      }
    }
  }

  private func read(reason: String, cancel: String?, result: @escaping FlutterResult) {
    DispatchQueue.global(qos: .userInitiated).async {
      let context = LAContext()
      context.localizedReason = reason
      if let cancel = cancel {
        context.localizedCancelTitle = cancel
      }
      var query = Self.baseQuery()
      query[kSecReturnData] = true
      query[kSecMatchLimit] = kSecMatchLimitOne
      query[kSecUseAuthenticationContext] = context
      var item: CFTypeRef?
      let status = SecItemCopyMatching(query as CFDictionary, &item)
      DispatchQueue.main.async {
        switch status {
        case errSecSuccess:
          if let data = item as? Data {
            result(FlutterStandardTypedData(bytes: data))
          } else {
            result(FlutterError(code: "failed", message: nil, details: nil))
          }
        case errSecUserCanceled:
          result(FlutterError(code: "cancelled", message: nil, details: nil))
        case errSecItemNotFound:
          // Also what a changed biometric enrolment looks like.
          result(FlutterError(code: "not_found", message: nil, details: nil))
        case errSecAuthFailed:
          result(FlutterError(code: "failed", message: nil, details: nil))
        default:
          result(FlutterError(code: "failed", message: "keychain \(status)", details: nil))
        }
      }
    }
  }

  private static func flutterError(for error: Error?) -> FlutterError {
    if let laError = error as? LAError {
      switch laError.code {
      case .userCancel, .appCancel, .systemCancel, .userFallback:
        return FlutterError(code: "cancelled", message: nil, details: nil)
      case .biometryNotAvailable, .biometryNotEnrolled, .passcodeNotSet:
        return FlutterError(code: "unavailable", message: nil, details: nil)
      default:
        break
      }
    }
    return FlutterError(code: "failed", message: nil, details: nil)
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
