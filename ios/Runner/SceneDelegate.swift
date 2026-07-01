import Flutter
import AVFoundation
import Photos
import Security
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  private var intentChannel: FlutterMethodChannel?
  private var keystoreChannel: FlutterMethodChannel?
  private var mediaChannel: FlutterMethodChannel?
  private let sharedPathKey = "hcv.share.path"
  private var appGroupId: String {
    Bundle.main.object(forInfoDictionaryKey: "SIGILLUMAppGroupId") as? String
      ?? "group.com.sigillum.hcv"
  }
  private var urlScheme: String {
    Bundle.main.object(forInfoDictionaryKey: "SIGILLUMURLScheme") as? String
      ?? "sigillum"
  }

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
      installKeystoreChannelIfNeeded()
      installMediaChannelIfNeeded()
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
        result(self.consumeSharedPath())
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    intentChannel = channel
    installKeystoreChannelIfNeeded()
    installMediaChannelIfNeeded()
  }

  private func consumeSharedPath() -> String? {
    if let path = UserDefaults.standard.string(forKey: "hcv.sharedPath"), !path.isEmpty {
      UserDefaults.standard.removeObject(forKey: "hcv.sharedPath")
      return path
    }

    if let path = UserDefaults.standard.string(forKey: sharedPathKey), !path.isEmpty {
      UserDefaults.standard.removeObject(forKey: sharedPathKey)
      return path
    }

    guard
      let defaults = UserDefaults(suiteName: appGroupId),
      let path = defaults.string(forKey: sharedPathKey),
      !path.isEmpty
    else {
      return nil
    }

    defaults.removeObject(forKey: sharedPathKey)
    return path
  }

  private func installMediaChannelIfNeeded() {
    if mediaChannel != nil {
      return
    }

    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }

    let channel = FlutterMethodChannel(
      name: "hcv.media",
      binaryMessenger: controller.binaryMessenger
    )

    channel.setMethodCallHandler { call, result in
      if call.method == "saveToPhotos" {
        guard
          let args = call.arguments as? [String: Any],
          let path = args["path"] as? String,
          !path.isEmpty
        else {
          result(FlutterError(code: "INVALID_PATH", message: "Path is empty", details: nil))
          return
        }

        self.saveToPhotos(path: path, result: result)
      } else if call.method == "extractVideoFrame" {
        guard
          let args = call.arguments as? [String: Any],
          let path = args["path"] as? String,
          !path.isEmpty
        else {
          result(FlutterError(code: "INVALID_PATH", message: "Path is empty", details: nil))
          return
        }

        let seconds = args["seconds"] as? Double ?? 0.5
        self.extractVideoFrame(path: path, seconds: seconds, result: result)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    mediaChannel = channel
  }

  private func saveToPhotos(path: String, result: @escaping FlutterResult) {
    let url = URL(fileURLWithPath: path)
    let lower = path.lowercased()

    PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
      guard status == .authorized || status == .limited else {
        DispatchQueue.main.async {
          result(false)
        }
        return
      }

      PHPhotoLibrary.shared().performChanges({
        if lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg") || lower.hasSuffix(".png") {
          PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
        } else {
          PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
        }
      }, completionHandler: { success, error in
        DispatchQueue.main.async {
          if let error = error {
            result(FlutterError(
              code: "PHOTO_SAVE_ERROR",
              message: error.localizedDescription,
              details: nil
            ))
          } else {
            result(success)
          }
        }
      })
    }
  }

  private func extractVideoFrame(
    path: String,
    seconds: Double,
    result: @escaping FlutterResult
  ) {
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        let url = URL(fileURLWithPath: path)
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        let image = try generator.copyCGImage(at: time, actualTime: nil)
        let uiImage = UIImage(cgImage: image)

        guard let data = uiImage.jpegData(compressionQuality: 0.92) else {
          throw NSError(
            domain: "SIGILLUM",
            code: 10,
            userInfo: [NSLocalizedDescriptionKey: "Frame JPEG creation failed"]
          )
        }

        let fileName = "hcv_frame_\(Int(Date().timeIntervalSince1970 * 1000)).jpg"
        let output = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: output, options: .atomic)

        DispatchQueue.main.async {
          result(output.path)
        }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(
            code: "FRAME_EXTRACTION_ERROR",
            message: error.localizedDescription,
            details: nil
          ))
        }
      }
    }
  }

  private func installKeystoreChannelIfNeeded() {
    if keystoreChannel != nil {
      return
    }

    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }

    let channel = FlutterMethodChannel(
      name: "hcv.keystore",
      binaryMessenger: controller.binaryMessenger
    )

    channel.setMethodCallHandler { call, result in
      do {
        if call.method == "sign" {
          guard
            let args = call.arguments as? [String: Any],
            let data = args["data"] as? String,
            !data.isEmpty
          else {
            result(FlutterError(
              code: "INVALID_DATA",
              message: "Data is empty",
              details: nil
            ))
            return
          }

          result(try self.signWithKeychain(data))
        } else if call.method == "getPublicKey" {
          result(try self.getPublicKeyMap())
        } else {
          result(FlutterMethodNotImplemented)
        }
      } catch {
        result(FlutterError(
          code: "KEYCHAIN_ERROR",
          message: error.localizedDescription,
          details: nil
        ))
      }
    }

    keystoreChannel = channel
  }

  private func handleSharedUrl(_ url: URL) {
    if url.scheme == urlScheme {
      handleSharedAppGroupFile()
      return
    }

    guard let path = copySharedFileToCache(url) else {
      return
    }

    UserDefaults.standard.set(path, forKey: "hcv.sharedPath")
    intentChannel?.invokeMethod("onSharedPath", arguments: path)
  }

  private func handleSharedAppGroupFile() {
    guard
      let defaults = UserDefaults(suiteName: appGroupId),
      let path = defaults.string(forKey: sharedPathKey)
    else {
      return
    }

    defaults.removeObject(forKey: sharedPathKey)
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

  private func getOrCreatePrivateKey() throws -> SecKey {
    let tag = "com.sigillum.hcv.signing.rsa.v1".data(using: .utf8)!

    let query: [String: Any] = [
      kSecClass as String: kSecClassKey,
      kSecAttrApplicationTag as String: tag,
      kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
      kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
      kSecReturnRef as String: true
    ]

    var item: CFTypeRef?
    let copyStatus = SecItemCopyMatching(query as CFDictionary, &item)

    if copyStatus == errSecSuccess, let key = item {
      return (key as! SecKey)
    }

    let attributes: [String: Any] = [
      kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
      kSecAttrKeySizeInBits as String: 2048,
      kSecPrivateKeyAttrs as String: [
        kSecAttrIsPermanent as String: true,
        kSecAttrApplicationTag as String: tag,
        kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
      ]
    ]

    var error: Unmanaged<CFError>?
    guard let key = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
      throw error!.takeRetainedValue() as Error
    }

    return key
  }

  private func signWithKeychain(_ value: String) throws -> String {
    let privateKey = try getOrCreatePrivateKey()
    let data = value.data(using: .utf8)!
    let algorithm = SecKeyAlgorithm.rsaSignatureMessagePKCS1v15SHA256

    guard SecKeyIsAlgorithmSupported(privateKey, .sign, algorithm) else {
      throw NSError(
        domain: "SIGILLUM",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "RSA SHA-256 signing not supported"]
      )
    }

    var error: Unmanaged<CFError>?
    guard let signature = SecKeyCreateSignature(
      privateKey,
      algorithm,
      data as CFData,
      &error
    ) as Data? else {
      throw error!.takeRetainedValue() as Error
    }

    return signature.base64EncodedString()
  }

  private func getPublicKeyMap() throws -> [String: String] {
    let privateKey = try getOrCreatePrivateKey()

    guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
      throw NSError(
        domain: "SIGILLUM",
        code: 2,
        userInfo: [NSLocalizedDescriptionKey: "Public key not available"]
      )
    }

    var error: Unmanaged<CFError>?
    guard let publicData = SecKeyCopyExternalRepresentation(
      publicKey,
      &error
    ) as Data? else {
      throw error!.takeRetainedValue() as Error
    }

    let components = try parseRsaPublicKey(publicData)

    return [
      "modulus": components.modulus.base64EncodedString(),
      "exponent": components.exponent.base64EncodedString()
    ]
  }

  private func parseRsaPublicKey(_ data: Data) throws -> (modulus: Data, exponent: Data) {
    var index = 0

    func readByte() throws -> UInt8 {
      guard index < data.count else {
        throw NSError(domain: "SIGILLUM", code: 3)
      }

      let byte = data[index]
      index += 1
      return byte
    }

    func readLength() throws -> Int {
      let first = try readByte()

      if first < 0x80 {
        return Int(first)
      }

      let count = Int(first & 0x7f)
      var length = 0

      for _ in 0..<count {
        length = (length << 8) + Int(try readByte())
      }

      return length
    }

    func readInteger() throws -> Data {
      guard try readByte() == 0x02 else {
        throw NSError(domain: "SIGILLUM", code: 4)
      }

      let length = try readLength()
      guard index + length <= data.count else {
        throw NSError(domain: "SIGILLUM", code: 5)
      }

      var value = data.subdata(in: index..<(index + length))
      index += length

      while value.count > 1 && value.first == 0 {
        value.removeFirst()
      }

      return value
    }

    guard try readByte() == 0x30 else {
      throw NSError(domain: "SIGILLUM", code: 6)
    }

    _ = try readLength()

    let modulus = try readInteger()
    let exponent = try readInteger()

    return (modulus, exponent)
  }
}
