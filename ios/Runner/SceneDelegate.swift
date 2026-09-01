import Flutter
import AVFoundation
import Photos
import PhotosUI
import UniformTypeIdentifiers
import Security
import StoreKit
import Speech
import QuartzCore
import UIKit


private final class HCVStorePriceLookup: NSObject, SKProductsRequestDelegate, SKRequestDelegate {
  private var request: SKProductsRequest?
  private let completion: ([String: String]?, Error?) -> Void

  init(productIds: [String], completion: @escaping ([String: String]?, Error?) -> Void) {
    self.completion = completion
    super.init()
    let lookup = SKProductsRequest(productIdentifiers: Set(productIds))
    request = lookup
    lookup.delegate = self
  }

  func start() {
    request?.start()
  }

  func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    var prices: [String: String] = [:]
    for product in response.products {
      formatter.locale = product.priceLocale
      if let rendered = formatter.string(from: product.price) {
        prices[product.productIdentifier] = rendered
      }
    }
    completion(prices, nil)
  }

  func request(_ request: SKRequest, didFailWithError error: Error) {
    completion(nil, error)
  }
}

class SceneDelegate: FlutterSceneDelegate, PHPickerViewControllerDelegate {
  private var intentChannel: FlutterMethodChannel?
  private var keystoreChannel: FlutterMethodChannel?
  private var mediaChannel: FlutterMethodChannel?
  private var storePriceLookups: [HCVStorePriceLookup] = []
  private var pendingOriginalPhotoResult: FlutterResult?
  private var speechTask: SFSpeechRecognitionTask?
  private var lastDeliveredSharedPath: String?
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

  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    installIntentChannel()
    stageSharedPathFromAppGroupIfNeeded()

    if let path = UserDefaults.standard.string(forKey: "hcv.sharedPath"),
       !path.isEmpty {
      deliverSharedPath(path)
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
        if let path = self.consumeSharedPath() {
          self.lastDeliveredSharedPath = path
          result(path)
        } else {
          result(nil)
        }
      } else if call.method == "ackSharedPath" {
        let args = call.arguments as? [String: Any]
        let acknowledgedPath = args?["path"] as? String
        let pendingPath = UserDefaults.standard.string(forKey: "hcv.sharedPath")
        if acknowledgedPath == nil || acknowledgedPath == pendingPath {
          UserDefaults.standard.removeObject(forKey: "hcv.sharedPath")
        }
        result(true)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    intentChannel = channel
    installKeystoreChannelIfNeeded()
    installMediaChannelIfNeeded()
  }

  private func deliverSharedPath(_ path: String) {
    guard !path.isEmpty else {
      return
    }

    UserDefaults.standard.removeObject(forKey: sharedPathKey)
    UserDefaults.standard.set(path, forKey: "hcv.sharedPath")
    UserDefaults.standard.synchronize()
    lastDeliveredSharedPath = path

    guard intentChannel != nil else {
      return
    }

    intentChannel?.invokeMethod("onSharedPath", arguments: path)
  }

  private func stageSharedPathFromAppGroupIfNeeded() {
    guard
      let defaults = UserDefaults(suiteName: appGroupId),
      let path = defaults.string(forKey: sharedPathKey),
      !path.isEmpty
    else {
      return
    }

    UserDefaults.standard.set(path, forKey: "hcv.sharedPath")
    UserDefaults.standard.synchronize()
    defaults.removeObject(forKey: sharedPathKey)
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
      } else if call.method == "pickOriginalPhoto" {
        self.pickOriginalPhoto(result: result)
      } else if call.method == "localizedProductPrices" {
        guard
          let args = call.arguments as? [String: Any],
          let ids = args["productIds"] as? [String],
          !ids.isEmpty
        else {
          result(FlutterError(
            code: "INVALID_PRODUCT_IDS",
            message: "No App Store product identifiers were supplied",
            details: nil
          ))
          return
        }

        self.localizedProductPrices(productIds: ids, result: result)
      } else if call.method == "validateImageForOcr" {
        guard
          let args = call.arguments as? [String: Any],
          let path = args["path"] as? String,
          !path.isEmpty
        else {
          result(false)
          return
        }
        self.validateImageForOcr(path: path, result: result)
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
      } else if call.method == "transcribeVideo" {
        guard
          let args = call.arguments as? [String: Any],
          let path = args["path"] as? String,
          !path.isEmpty
        else {
          result(FlutterError(code: "INVALID_PATH", message: "Path is empty", details: nil))
          return
        }
        self.transcribeVideo(
          path: path,
          languageCode: (args["languageCode"] as? String) ?? "it",
          result: result
        )
      } else if call.method == "burnSubtitles" {
        guard
          let args = call.arguments as? [String: Any],
          let path = args["path"] as? String,
          let outputPath = args["outputPath"] as? String,
          let segments = args["segments"] as? [[String: Any]],
          !path.isEmpty,
          !outputPath.isEmpty
        else {
          result(FlutterError(code: "INVALID_SUBTITLE_EXPORT", message: "Parametri sottotitoli non validi.", details: nil))
          return
        }
        self.burnSubtitles(videoPath: path, outputPath: outputPath, segments: segments, result: result)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    mediaChannel = channel
  }


  private func validateImageForOcr(path: String, result: @escaping FlutterResult) {
    DispatchQueue.global(qos: .userInitiated).async {
      let fileExists = FileManager.default.fileExists(atPath: path)
      let image = fileExists ? UIImage(contentsOfFile: path) : nil
      DispatchQueue.main.async {
        result(image != nil)
      }
    }
  }

  private func pickOriginalPhoto(result: @escaping FlutterResult) {
    guard let presenter = self.window?.rootViewController else {
      result(FlutterError(
        code: "PHOTO_PICK_NO_PRESENTER",
        message: "Unable to present Photos picker",
        details: nil
      ))
      return
    }

    if let staleResult = pendingOriginalPhotoResult {
      if presenter.presentedViewController is PHPickerViewController {
        result(FlutterError(
          code: "PHOTO_PICK_BUSY",
          message: "Another original-photo selection is already active",
          details: nil
        ))
        return
      }
      pendingOriginalPhotoResult = nil
      staleResult(FlutterError(
        code: "PHOTO_PICK_STALE_RESET",
        message: "A stale photo selection was reset",
        details: nil
      ))
    }

    // PHPicker grants access to the item explicitly chosen by the user and
    // must remain usable even when Photos permission is LIMITED or DENIED.
    // If full PHAsset access is available, resolution below still prefers the
    // original PHAssetResource bytes for exact SIGILLUM hash verification.
    pendingOriginalPhotoResult = result
    var configuration = PHPickerConfiguration(photoLibrary: PHPhotoLibrary.shared())
    configuration.filter = .images
    configuration.selectionLimit = 1
    configuration.preferredAssetRepresentationMode = .current
    let picker = PHPickerViewController(configuration: configuration)
    picker.delegate = self
    presenter.present(picker, animated: true)
  }

  private func takePendingOriginalPhotoResult() -> FlutterResult? {
    let flutterResult = pendingOriginalPhotoResult
    pendingOriginalPhotoResult = nil
    return flutterResult
  }

  private func copyPickerPhotoRepresentation(
    _ selection: PHPickerResult,
    result: @escaping FlutterResult,
    originalError: FlutterError? = nil
  ) {
    let provider = selection.itemProvider
    guard provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) else {
      result(originalError ?? FlutterError(
        code: "PHOTO_PICKER_FILE_UNAVAILABLE",
        message: "Selected photo file is unavailable",
        details: nil
      ))
      return
    }

    provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { [weak self] url, error in
      guard let self = self else { return }
      guard let source = url else {
        DispatchQueue.main.async {
          result(originalError ?? FlutterError(
            code: "PHOTO_PICKER_FILE_ERROR",
            message: error?.localizedDescription ?? "Unable to read selected photo",
            details: nil
          ))
        }
        return
      }

      let rawExtension = source.pathExtension
      let fileExtension = rawExtension.isEmpty ? "jpg" : rawExtension
      let suggestedLeaf = provider.suggestedName.map {
        URL(fileURLWithPath: $0).lastPathComponent
      }?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      let suggestedExtension = URL(fileURLWithPath: suggestedLeaf).pathExtension
      let preservedName: String
      if suggestedLeaf.isEmpty {
        preservedName = "hcv_picker_\(UUID().uuidString).\(fileExtension)"
      } else if suggestedExtension.isEmpty {
        preservedName = "hcv_picker_\(UUID().uuidString)_\(suggestedLeaf).\(fileExtension)"
      } else {
        preservedName = "hcv_picker_\(UUID().uuidString)_\(suggestedLeaf)"
      }
      let output = FileManager.default.temporaryDirectory.appendingPathComponent(
        preservedName
      )

      do {
        try? FileManager.default.removeItem(at: output)
        try FileManager.default.copyItem(at: source, to: output)
        DispatchQueue.main.async {
          result(output.path)
        }
      } catch {
        DispatchQueue.main.async {
          result(originalError ?? FlutterError(
            code: "PHOTO_PICKER_FILE_ERROR",
            message: error.localizedDescription,
            details: nil
          ))
        }
      }
    }
  }

  private func resolveOriginalPhotoSelection(
    _ results: [PHPickerResult],
    result: @escaping FlutterResult
  ) {
    guard let selection = results.first else {
      result(nil)
      return
    }

    // Exact original bytes remain the first choice whenever the selected item
    // is visible through PhotoKit. Under LIMITED Photos access PHPicker can
    // legitimately return a user-selected item that PHAsset.fetchAssets cannot
    // query; in that case fall back to the file representation granted by the
    // picker instead of rejecting the photo.
    guard let assetIdentifier = selection.assetIdentifier else {
      copyPickerPhotoRepresentation(selection, result: result)
      return
    }

    let assets = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
    guard let asset = assets.firstObject else {
      copyPickerPhotoRepresentation(selection, result: result)
      return
    }

    let resources = PHAssetResource.assetResources(for: asset)
    let original = resources.first(where: { $0.type == .photo })
      ?? resources.first(where: { $0.type == .fullSizePhoto })
    guard let resource = original else {
      copyPickerPhotoRepresentation(selection, result: result)
      return
    }

    let originalLeaf = URL(fileURLWithPath: resource.originalFilename).lastPathComponent
    let rawExtension = URL(fileURLWithPath: originalLeaf).pathExtension
    let fileExtension = rawExtension.isEmpty ? "jpg" : rawExtension
    let preservedName = originalLeaf.isEmpty
      ? "hcv_original_\(UUID().uuidString).\(fileExtension)"
      : "hcv_original_\(UUID().uuidString)_\(originalLeaf)"
    let output = FileManager.default.temporaryDirectory.appendingPathComponent(
      preservedName
    )
    try? FileManager.default.removeItem(at: output)

    let options = PHAssetResourceRequestOptions()
    options.isNetworkAccessAllowed = true
    PHAssetResourceManager.default().writeData(
      for: resource,
      toFile: output,
      options: options
    ) { [weak self] error in
      DispatchQueue.main.async {
        guard let self = self else { return }
        if let error = error {
          self.copyPickerPhotoRepresentation(
            selection,
            result: result,
            originalError: FlutterError(
              code: "PHOTO_ORIGINAL_READ_ERROR",
              message: error.localizedDescription,
              details: nil
            )
          )
        } else {
          result(output.path)
        }
      }
    }
  }

  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    guard let flutterResult = takePendingOriginalPhotoResult() else {
      picker.dismiss(animated: true)
      return
    }
    picker.dismiss(animated: true) { [weak self] in
      guard let self = self else {
        flutterResult(nil)
        return
      }
      self.resolveOriginalPhotoSelection(results, result: flutterResult)
    }
  }

  private func localizedProductPrices(
    productIds: [String],
    result: @escaping FlutterResult
  ) {
    var lookup: HCVStorePriceLookup?
    lookup = HCVStorePriceLookup(productIds: productIds) { [weak self] prices, error in
      DispatchQueue.main.async {
        if let lookup = lookup {
          self?.storePriceLookups.removeAll { $0 === lookup }
        }
        if let error = error {
          result(FlutterError(
            code: "STORE_PRICE_LOOKUP_FAILED",
            message: error.localizedDescription,
            details: nil
          ))
        } else {
          result(prices ?? [:])
        }
      }
    }
    guard let retainedLookup = lookup else {
      result(FlutterError(
        code: "STORE_PRICE_LOOKUP_FAILED",
        message: "Unable to initialize App Store price lookup",
        details: nil
      ))
      return
    }
    storePriceLookups.append(retainedLookup)
    retainedLookup.start()
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

  private func burnSubtitles(
    videoPath: String,
    outputPath: String,
    segments: [[String: Any]],
    result: @escaping FlutterResult
  ) {
    let sourceURL = URL(fileURLWithPath: videoPath)
    let outputURL = URL(fileURLWithPath: outputPath)
    let asset = AVURLAsset(url: sourceURL)

    guard let sourceVideoTrack = asset.tracks(withMediaType: .video).first else {
      result(FlutterError(code: "SUBTITLE_VIDEO_TRACK_MISSING", message: "Traccia video non disponibile.", details: nil))
      return
    }
    let composition = AVMutableComposition()
    guard let compositionVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
      result(FlutterError(code: "SUBTITLE_COMPOSITION_ERROR", message: "Impossibile preparare la copia sottotitolata.", details: nil))
      return
    }
    do {
      try compositionVideoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: asset.duration), of: sourceVideoTrack, at: .zero)
      if let sourceAudioTrack = asset.tracks(withMediaType: .audio).first,
         let compositionAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
        try compositionAudioTrack.insertTimeRange(CMTimeRange(start: .zero, duration: asset.duration), of: sourceAudioTrack, at: .zero)
      }
    } catch {
      result(FlutterError(code: "SUBTITLE_COMPOSITION_ERROR", message: error.localizedDescription, details: nil))
      return
    }

    let naturalRect = CGRect(origin: .zero, size: sourceVideoTrack.naturalSize)
    let transformedRect = naturalRect.applying(sourceVideoTrack.preferredTransform)
    let renderSize = CGSize(width: abs(transformedRect.width), height: abs(transformedRect.height))
    guard renderSize.width > 0, renderSize.height > 0 else {
      result(FlutterError(code: "SUBTITLE_RENDER_SIZE_ERROR", message: "Dimensioni video non valide.", details: nil))
      return
    }
    var normalizedTransform = sourceVideoTrack.preferredTransform
    normalizedTransform.tx -= transformedRect.origin.x
    normalizedTransform.ty -= transformedRect.origin.y
    let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideoTrack)
    layerInstruction.setTransform(normalizedTransform, at: .zero)
    let instruction = AVMutableVideoCompositionInstruction()
    instruction.timeRange = CMTimeRange(start: .zero, duration: composition.duration)
    instruction.layerInstructions = [layerInstruction]
    let videoComposition = AVMutableVideoComposition()
    videoComposition.renderSize = renderSize
    videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
    videoComposition.instructions = [instruction]

    let parentLayer = CALayer()
    parentLayer.frame = CGRect(origin: .zero, size: renderSize)
    let videoLayer = CALayer()
    videoLayer.frame = parentLayer.frame
    let overlayLayer = CALayer()
    overlayLayer.frame = parentLayer.frame
    parentLayer.addSublayer(videoLayer)
    parentLayer.addSublayer(overlayLayer)
    let horizontalInset = max(22.0, renderSize.width * 0.055)
    let captionHeight = max(76.0, renderSize.height * 0.13)
    let captionY = max(34.0, renderSize.height * 0.065)
    let fontSize = max(24.0, min(46.0, renderSize.width * 0.052))

    for item in segments {
      guard let text = item["text"] as? String,
            !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
      let start = (item["start"] as? NSNumber)?.doubleValue ?? 0
      let duration = max(0.45, (item["duration"] as? NSNumber)?.doubleValue ?? 1.0)
      let captionLayer = CATextLayer()
      captionLayer.string = text
      captionLayer.frame = CGRect(x: horizontalInset, y: captionY, width: renderSize.width - (horizontalInset * 2), height: captionHeight)
      captionLayer.alignmentMode = .center
      captionLayer.truncationMode = .end
      captionLayer.isWrapped = true
      captionLayer.fontSize = fontSize
      captionLayer.contentsScale = 2.0
      captionLayer.foregroundColor = UIColor.white.cgColor
      captionLayer.backgroundColor = UIColor.black.withAlphaComponent(0.72).cgColor
      captionLayer.cornerRadius = max(10.0, renderSize.width * 0.018)
      captionLayer.masksToBounds = true
      captionLayer.opacity = 0
      let visibility = CAKeyframeAnimation(keyPath: "opacity")
      visibility.values = [0.0, 1.0, 1.0, 0.0]
      visibility.keyTimes = [0.0, 0.03, 0.97, 1.0]
      visibility.beginTime = AVCoreAnimationBeginTimeAtZero + max(0, start)
      visibility.duration = duration
      visibility.isRemovedOnCompletion = false
      visibility.fillMode = .both
      captionLayer.add(visibility, forKey: "sigillumCaptionVisibility")
      overlayLayer.addSublayer(captionLayer)
    }
    videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parentLayer)

    do {
      try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
      if FileManager.default.fileExists(atPath: outputURL.path) { try FileManager.default.removeItem(at: outputURL) }
    } catch {
      result(FlutterError(code: "SUBTITLE_OUTPUT_ERROR", message: error.localizedDescription, details: nil))
      return
    }
    guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
      result(FlutterError(code: "SUBTITLE_EXPORT_ERROR", message: "Esportazione video non disponibile.", details: nil))
      return
    }
    exporter.outputURL = outputURL
    exporter.outputFileType = .mp4
    exporter.shouldOptimizeForNetworkUse = true
    exporter.videoComposition = videoComposition
    exporter.exportAsynchronously {
      DispatchQueue.main.async {
        switch exporter.status {
        case .completed:
          result(["path": outputPath])
        case .failed, .cancelled:
          result(FlutterError(code: "SUBTITLE_EXPORT_ERROR", message: exporter.error?.localizedDescription ?? "Creazione del video sottotitolato non riuscita.", details: nil))
        default:
          result(FlutterError(code: "SUBTITLE_EXPORT_ERROR", message: "Esportazione video non completata.", details: nil))
        }
      }
    }
  }

  private func speechLocaleIdentifier(_ languageCode: String) -> String {
    let normalized = languageCode.lowercased()
    if normalized.hasPrefix("it") { return "it-IT" }
    if normalized.hasPrefix("en") { return "en-US" }
    if normalized.hasPrefix("fr") { return "fr-FR" }
    if normalized.hasPrefix("de") { return "de-DE" }
    if normalized.hasPrefix("es") { return "es-ES" }
    if normalized.hasPrefix("ro") { return "ro-RO" }
    return Locale.preferredLanguages.first ?? "it-IT"
  }

  private func transcribeVideo(
    path: String,
    languageCode: String,
    result: @escaping FlutterResult
  ) {
    SFSpeechRecognizer.requestAuthorization { status in
      guard status == .authorized else {
        DispatchQueue.main.async {
          result(FlutterError(
            code: "SPEECH_PERMISSION_DENIED",
            message: "Autorizza Riconoscimento vocale nelle impostazioni di iPhone.",
            details: nil
          ))
        }
        return
      }

      let videoURL = URL(fileURLWithPath: path)
      self.exportAudioForSpeech(videoURL: videoURL) { audioURL, exportError in
        if let exportError = exportError {
          DispatchQueue.main.async {
            result(FlutterError(
              code: "AUDIO_EXPORT_ERROR",
              message: exportError.localizedDescription,
              details: nil
            ))
          }
          return
        }
        guard let audioURL = audioURL else {
          DispatchQueue.main.async {
            result(FlutterError(
              code: "AUDIO_EXPORT_ERROR",
              message: "Audio del video non disponibile.",
              details: nil
            ))
          }
          return
        }

        let localeIdentifier = self.speechLocaleIdentifier(languageCode)
        guard let recognizer = SFSpeechRecognizer(
          locale: Locale(identifier: localeIdentifier)
        ), recognizer.isAvailable else {
          try? FileManager.default.removeItem(at: audioURL)
          DispatchQueue.main.async {
            result(FlutterError(
              code: "SPEECH_UNAVAILABLE",
              message: "Riconoscimento vocale non disponibile in questo momento.",
              details: ["locale": localeIdentifier]
            ))
          }
          return
        }

        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        if #available(iOS 16.0, *) {
          request.addsPunctuation = true
        }

        var completed = false
        var bestText = ""
        var bestSegments = [[String: Any]]()
        var bestCoverage = -1.0
        var bestCharacterCount = 0

        // Partial hypotheses from Apple Speech may revise themselves while the
        // file is still being processed. Keep a timestamped timeline as well
        // as the best cumulative hypothesis so words from an earlier portion
        // of the video cannot disappear simply because a later partial result
        // starts farther forward.
        var timeline = [Int: [String: Any]]()

        func capture(_ response: SFSpeechRecognitionResult) {
          let transcription = response.bestTranscription
          let text = transcription.formattedString.trimmingCharacters(
            in: .whitespacesAndNewlines
          )
          let segments = transcription.segments.map { segment in
            return [
              "text": segment.substring,
              "start": segment.timestamp,
              "duration": segment.duration,
            ] as [String: Any]
          }

          for segment in transcription.segments {
            // 80 ms buckets absorb small timestamp shifts between successive
            // hypotheses. Newer recognizer output replaces the same moment;
            // moments omitted by a later partial remain preserved.
            let bucket = Int((segment.timestamp / 0.08).rounded())
            timeline[bucket] = [
              "text": segment.substring,
              "start": segment.timestamp,
              "duration": segment.duration,
            ]
          }

          let coverage = transcription.segments.last.map {
            $0.timestamp + $0.duration
          } ?? 0
          let characterCount = text.count
          if coverage > bestCoverage + 0.05 ||
             (abs(coverage - bestCoverage) <= 0.05 && characterCount > bestCharacterCount) ||
             characterCount > bestCharacterCount + 12 {
            bestText = text
            bestSegments = segments
            bestCoverage = coverage
            bestCharacterCount = characterCount
          }
        }

        func mergedTimeline() -> [[String: Any]] {
          return timeline.values.sorted { left, right in
            let a = left["start"] as? Double ?? 0
            let b = right["start"] as? Double ?? 0
            return a < b
          }
        }

        func mergedText(_ segments: [[String: Any]]) -> String {
          return segments.compactMap { item in
            (item["text"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
          }.filter { !$0.isEmpty }.joined(separator: " ")
        }

        func finishSuccess() {
          if completed { return }
          completed = true
          try? FileManager.default.removeItem(at: audioURL)
          self.speechTask = nil

          let timelineSegments = mergedTimeline()
          let timelineText = mergedText(timelineSegments)
          let selectedSegments = timelineSegments.count >= bestSegments.count
            ? timelineSegments
            : bestSegments
          let selectedText = timelineText.count >= bestText.count
            ? timelineText
            : bestText
          let sourceDuration = AVURLAsset(url: videoURL).duration.seconds

          DispatchQueue.main.async {
            result([
              "text": selectedText,
              "segments": selectedSegments,
              "locale": localeIdentifier,
              "duration": sourceDuration.isFinite ? sourceDuration : 0,
            ])
          }
        }

        self.speechTask?.cancel()
        self.speechTask = recognizer.recognitionTask(with: request) { response, error in
          if completed { return }
          if let response = response {
            capture(response)
            if response.isFinal {
              finishSuccess()
              return
            }
          }
          if let error = error {
            if !bestText.isEmpty || !bestSegments.isEmpty || !timeline.isEmpty {
              finishSuccess()
              return
            }
            completed = true
            try? FileManager.default.removeItem(at: audioURL)
            self.speechTask = nil
            DispatchQueue.main.async {
              result(FlutterError(
                code: "SPEECH_RECOGNITION_ERROR",
                message: error.localizedDescription,
                details: ["locale": localeIdentifier]
              ))
            }
          }
        }

        // File recognition should be allowed to cover the whole source. Some
        // recognitions return useful cumulative partials without a final event,
        // so finish only after a duration-based grace period.
        let audioDuration = AVURLAsset(url: audioURL).duration.seconds
        let timeout = max(12.0, min(120.0, audioDuration + 20.0))
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
          if completed { return }
          if !bestText.isEmpty || !bestSegments.isEmpty || !timeline.isEmpty {
            self.speechTask?.finish()
            finishSuccess()
          } else {
            self.speechTask?.cancel()
            completed = true
            try? FileManager.default.removeItem(at: audioURL)
            self.speechTask = nil
            result(FlutterError(
              code: "NO_SPEECH",
              message: "Non è stato rilevato parlato nel video.",
              details: ["locale": localeIdentifier]
            ))
          }
        }
      }
    }
  }

  private func exportAudioForSpeech(
    videoURL: URL,
    completion: @escaping (URL?, Error?) -> Void
  ) {
    let asset = AVURLAsset(url: videoURL)
    guard let exporter = AVAssetExportSession(
      asset: asset,
      presetName: AVAssetExportPresetAppleM4A
    ) else {
      completion(nil, NSError(
        domain: "SIGILLUM",
        code: 20,
        userInfo: [NSLocalizedDescriptionKey: "Impossibile preparare l'audio del video."]
      ))
      return
    }

    let output = FileManager.default.temporaryDirectory.appendingPathComponent(
      "sigillum_speech_\(Int(Date().timeIntervalSince1970 * 1000)).m4a"
    )
    try? FileManager.default.removeItem(at: output)
    exporter.outputURL = output
    exporter.outputFileType = .m4a
    exporter.exportAsynchronously {
      switch exporter.status {
      case .completed:
        completion(output, nil)
      case .failed, .cancelled:
        completion(nil, exporter.error ?? NSError(
          domain: "SIGILLUM",
          code: 21,
          userInfo: [NSLocalizedDescriptionKey: "Estrazione audio non riuscita."]
        ))
      default:
        completion(nil, NSError(
          domain: "SIGILLUM",
          code: 22,
          userInfo: [NSLocalizedDescriptionKey: "Estrazione audio non completata."]
        ))
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
        } else if call.method == "setSecret" {
          guard
            let args = call.arguments as? [String: Any],
            let key = args["key"] as? String,
            let value = args["value"] as? String,
            !key.isEmpty
          else {
            result(FlutterError(code: "INVALID_SECRET", message: "Secret key is empty", details: nil))
            return
          }
          try self.setKeychainSecret(key: key, value: value)
          result(nil)
        } else if call.method == "getSecret" {
          guard
            let args = call.arguments as? [String: Any],
            let key = args["key"] as? String,
            !key.isEmpty
          else {
            result(FlutterError(code: "INVALID_SECRET", message: "Secret key is empty", details: nil))
            return
          }
          result(try self.getKeychainSecret(key: key))
        } else if call.method == "deleteSecret" {
          guard
            let args = call.arguments as? [String: Any],
            let key = args["key"] as? String,
            !key.isEmpty
          else {
            result(FlutterError(code: "INVALID_SECRET", message: "Secret key is empty", details: nil))
            return
          }
          try self.deleteKeychainSecret(key: key)
          result(nil)
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

    deliverSharedPath(path)
  }

  private func handleSharedAppGroupFile() {
    guard
      let defaults = UserDefaults(suiteName: appGroupId),
      let path = defaults.string(forKey: sharedPathKey)
    else {
      return
    }

    defaults.removeObject(forKey: sharedPathKey)
    deliverSharedPath(path)
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

  private let secretService = "com.sigillum.hcv.secure"

  private func secretQuery(key: String) -> [String: Any] {
    return [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: secretService,
      kSecAttrAccount as String: key
    ]
  }

  private func setKeychainSecret(key: String, value: String) throws {
    var query = secretQuery(key: key)
    SecItemDelete(query as CFDictionary)
    query[kSecValueData as String] = Data(value.utf8)
    query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    let status = SecItemAdd(query as CFDictionary, nil)
    guard status == errSecSuccess else {
      throw NSError(
        domain: NSOSStatusErrorDomain,
        code: Int(status),
        userInfo: [NSLocalizedDescriptionKey: "Unable to save secure account session"]
      )
    }
  }

  private func getKeychainSecret(key: String) throws -> String? {
    var query = secretQuery(key: key)
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    if status == errSecItemNotFound {
      return nil
    }
    guard status == errSecSuccess, let data = item as? Data else {
      throw NSError(
        domain: NSOSStatusErrorDomain,
        code: Int(status),
        userInfo: [NSLocalizedDescriptionKey: "Unable to read secure account session"]
      )
    }
    return String(data: data, encoding: .utf8)
  }

  private func deleteKeychainSecret(key: String) throws {
    let status = SecItemDelete(secretQuery(key: key) as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw NSError(
        domain: NSOSStatusErrorDomain,
        code: Int(status),
        userInfo: [NSLocalizedDescriptionKey: "Unable to delete secure account session"]
      )
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
