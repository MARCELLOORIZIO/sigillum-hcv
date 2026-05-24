import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  private var intentChannel: FlutterMethodChannel?

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    installIntentChannel()

    if let url = connectionOptions.urlContexts.first?.url {
      handleSharedUrl(url)
    }
  }

  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    super.scene(scene, openURLContexts: URLContexts)
    installIntentChannel()

    if let url = URLContexts.first?.url {
      handleSharedUrl(url)
    }
  }

  private func installIntentChannel() {
    if intentChannel != nil {
      return
    }

    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }

    let channel = FlutterMethodChannel(
      name: "hcv.intent",
      binaryMessenger: controller.binaryMessenger
    )

    channel.setMethodCallHandler { call, result in
      if call.method == "getSharedPath" {
        let path = UserDefaults.standard.string(forKey: "hcv.sharedPath")
        UserDefaults.standard.removeObject(forKey: "hcv.sharedPath")
        result(path)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    intentChannel = channel
  }

  private func handleSharedUrl(_ url: URL) {
    guard let path = copySharedFileToCache(url) else {
      return
    }

    UserDefaults.standard.set(path, forKey: "hcv.sharedPath")
    intentChannel?.invokeMethod("onSharedPath", arguments: path)
  }

  private func copySharedFileToCache(_ url: URL) -> String? {
    let didAccess = url.startAccessingSecurityScopedResource()
    defer {
      if didAccess {
        url.stopAccessingSecurityScopedResource()
      }
    }

    do {
      let fileManager = FileManager.default
      let cacheDir = try fileManager.url(
        for: .cachesDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
      )

      let ext = url.pathExtension.isEmpty ? "bin" : url.pathExtension
      let fileName = "shared_\(Int(Date().timeIntervalSince1970 * 1000)).\(ext)"
      let destination = cacheDir.appendingPathComponent(fileName)

      if fileManager.fileExists(atPath: destination.path) {
        try fileManager.removeItem(at: destination)
      }

      try fileManager.copyItem(at: url, to: destination)
      return destination.path
    } catch {
      return nil
    }
  }
}
