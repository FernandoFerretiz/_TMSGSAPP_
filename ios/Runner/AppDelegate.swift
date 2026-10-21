import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

  /// Must be retained for as long as the "Open in…" menu is on screen —
  /// UIDocumentInteractionController does not keep itself alive.
  private var documentInteractionController: UIDocumentInteractionController?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SultanShareChannel") {
      let channel = FlutterMethodChannel(
        name: "com.sultanx.tms/share",
        binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { [weak self] call, result in
        self?.handleShare(call, result: result)
      }
    }
  }

  // MARK: - ShareService bridge (see lib/app/core/share/share_service.dart)
  //
  // iOS sandboxes cross-app sharing: there is no public API to hand a file
  // straight to one specific app the way Android's ACTION_SEND + setPackage
  // does — a third-party app's Share Extension cannot be pre-selected or
  // launched directly. The closest Apple-sanctioned primitive is
  // UIDocumentInteractionController's "Open in…" menu: it is scoped to apps
  // that registered as *document providers* for the file's type, which does
  // NOT include Instagram/Facebook/Gmail (those only register as ShareSheet
  // extensions, a different mechanism) — so it still satisfies "no generic
  // noisy share sheet". The tradeoffs vs. Android: the user must tap the
  // target app once inside that native menu (no single-tap direct launch),
  // and the pre-filled text cannot travel alongside the file — WhatsApp's
  // document import on iOS has no caption parameter.
  private func handleShare(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isAppInstalled":
      guard let args = call.arguments as? [String: Any],
            let scheme = args["scheme"] as? String,
            let url = URL(string: "\(scheme)://")
      else {
        result(false)
        return
      }
      DispatchQueue.main.async {
        result(UIApplication.shared.canOpenURL(url))
      }

    case "shareFile":
      guard let args = call.arguments as? [String: Any],
            let filePath = args["filePath"] as? String
      else {
        result(false)
        return
      }

      let fileURL = URL(fileURLWithPath: filePath)

      DispatchQueue.main.async { [weak self] in
        guard let self = self,
              let rootViewController = self.window?.rootViewController,
              FileManager.default.fileExists(atPath: fileURL.path)
        else {
          result(false)
          return
        }

        let controller = UIDocumentInteractionController(url: fileURL)
        self.documentInteractionController = controller

        let anchor = CGRect(
          x: rootViewController.view.bounds.midX,
          y: rootViewController.view.bounds.midY,
          width: 1,
          height: 1
        )

        let presented = controller.presentOpenInMenu(
          from: anchor,
          in: rootViewController.view,
          animated: true
        )
        result(presented)
      }

    case "shareText":
      // Unlike shareFile, text-only has no document to hand off via
      // UIDocumentInteractionController — but WhatsApp/Telegram both
      // publish a sanctioned URL scheme for opening straight into a
      // compose screen with prefilled text (schemes already declared in
      // LSApplicationQueriesSchemes), so this still avoids the generic
      // share sheet like the file variant does.
      guard let args = call.arguments as? [String: Any],
            let scheme = args["scheme"] as? String,
            let text = args["text"] as? String,
            let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
      else {
        result(false)
        return
      }

      let urlString: String
      switch scheme {
      case "whatsapp":
        urlString = "whatsapp://send?text=\(encoded)"
      case "tg":
        urlString = "tg://msg?text=\(encoded)"
      default:
        result(false)
        return
      }

      guard let url = URL(string: urlString) else {
        result(false)
        return
      }

      DispatchQueue.main.async {
        UIApplication.shared.open(url, options: [:]) { success in
          result(success)
        }
      }

    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
