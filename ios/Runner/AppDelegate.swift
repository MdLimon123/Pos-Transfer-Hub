import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, UIDocumentInteractionControllerDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Needed so flutter_local_notifications can show banners while in foreground.
    UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()
    let channel = FlutterMethodChannel(name: "com.possaas.transferhub/storage", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      let args = call.arguments as? [String: Any]
      switch call.method {
      case "ensureStoragePermission":
        result(true) // iOS needs no permission for the app's own Documents folder.
      case "saveToDownloads":
        guard let source = args?["source"] as? String, let name = args?["name"] as? String else {
          result(FlutterError(code: "STORAGE_ERROR", message: "Bad arguments", details: nil)); return
        }
        do { result(try self?.saveToDocuments(source: source, name: name)) }
        catch { result(FlutterError(code: "STORAGE_ERROR", message: error.localizedDescription, details: nil)) }
      case "openFile":
        guard let location = args?["location"] as? String else {
          result(FlutterError(code: "STORAGE_ERROR", message: "Bad arguments", details: nil)); return
        }
        result(self?.openFile(location: location) ?? false)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Copies into Documents/TransferHub (visible in the Files app under
  /// "On My iPhone > Transfer Hub") and returns the absolute path.
  private func saveToDocuments(source: String, name: String) throws -> String {
    let fm = FileManager.default
    let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let dir = docs.appendingPathComponent("TransferHub", isDirectory: true)
    try fm.createDirectory(at: dir, withIntermediateDirectories: true)
    let ext = (name as NSString).pathExtension
    let base = (name as NSString).deletingPathExtension
    var target = dir.appendingPathComponent(name)
    var i = 1
    while fm.fileExists(atPath: target.path) {
      let n = ext.isEmpty ? "\(base) (\(i))" : "\(base) (\(i)).\(ext)"
      target = dir.appendingPathComponent(n)
      i += 1
    }
    try fm.copyItem(at: URL(fileURLWithPath: source), to: target)
    return target.path
  }

  private func openFile(location: String) -> Bool {
    guard FileManager.default.fileExists(atPath: location) else { return false }
    let present = {
      guard let vc = self.topViewController() else { return false }
      let controller = UIDocumentInteractionController(url: URL(fileURLWithPath: location))
      controller.delegate = self
      self.docController = controller
      if controller.presentPreview(animated: true) { return true }
      return controller.presentOpenInMenu(from: vc.view.bounds, in: vc.view, animated: true)
    }
    return Thread.isMainThread ? present() : DispatchQueue.main.sync(execute: present)
  }

  private var docController: UIDocumentInteractionController?

  func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
    return topViewController() ?? UIViewController()
  }

  private func topViewController() -> UIViewController? {
    let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    var vc = scene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
    while let presented = vc?.presentedViewController { vc = presented }
    return vc
  }
}
