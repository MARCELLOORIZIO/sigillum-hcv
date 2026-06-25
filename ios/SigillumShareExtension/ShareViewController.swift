import MobileCoreServices
import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
  private let sharedPathKey = "hcv.share.path"
  private var appGroupId: String {
    Bundle.main.object(forInfoDictionaryKey: "SIGILLUMAppGroupId") as? String
      ?? "group.com.sigillum.hcv"
  }
  private var urlScheme: String {
    Bundle.main.object(forInfoDictionaryKey: "SIGILLUMURLScheme") as? String
      ?? "sigillum"
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = UIColor.systemBackground
    handleSharedItem()
  }

  private func handleSharedItem() {
    guard
      let item = extensionContext?.inputItems.first as? NSExtensionItem,
      let providers = item.attachments,
      let provider = providers.first
    else {
      finish()
      return
    }

    if load(provider, type: UTType.movie.identifier) { return }
    if load(provider, type: UTType.mpeg4Movie.identifier) { return }
    if load(provider, type: UTType.quickTimeMovie.identifier) { return }
    if load(provider, type: UTType.image.identifier) { return }
    if load(provider, type: UTType.jpeg.identifier) { return }
    if load(provider, type: UTType.png.identifier) { return }
    if load(provider, type: UTType.plainText.identifier) { return }
    if load(provider, type: UTType.fileURL.identifier) { return }

    finish()
  }

  private func load(_ provider: NSItemProvider, type: String) -> Bool {
    guard provider.hasItemConformingToTypeIdentifier(type) else {
      return false
    }

    provider.loadItem(forTypeIdentifier: type, options: nil) { [weak self] item, _ in
      self?.storeAndOpen(item, preferredType: type)
    }

    return true
  }

  private func storeAndOpen(_ item: NSSecureCoding?, preferredType: String) {
    guard let destination = copyToSharedContainer(item, preferredType: preferredType) else {
      finish()
      return
    }

    let defaults = UserDefaults(suiteName: appGroupId)
    defaults?.set(destination.path, forKey: sharedPathKey)
    defaults?.synchronize()
    openHostAppAndFinish()
  }

  private func copyToSharedContainer(
    _ item: NSSecureCoding?,
    preferredType: String
  ) -> URL? {
    guard let container = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: appGroupId
    ) else {
      return nil
    }

    let inbox = container.appendingPathComponent("SharedInbox", isDirectory: true)

    do {
      try FileManager.default.createDirectory(
        at: inbox,
        withIntermediateDirectories: true
      )

      if let url = item as? URL {
        let ext = url.pathExtension.isEmpty ? extensionForType(preferredType) : url.pathExtension
        let destination = inbox.appendingPathComponent(fileName(ext: ext))
        if FileManager.default.fileExists(atPath: destination.path) {
          try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: url, to: destination)
        return destination
      }

      if let image = item as? UIImage, let data = image.jpegData(compressionQuality: 0.95) {
        let destination = inbox.appendingPathComponent(fileName(ext: "jpg"))
        try data.write(to: destination, options: .atomic)
        return destination
      }

      if let text = item as? String, let data = text.data(using: .utf8) {
        let destination = inbox.appendingPathComponent(fileName(ext: "txt"))
        try data.write(to: destination, options: .atomic)
        return destination
      }
    } catch {
      return nil
    }

    return nil
  }

  private func fileName(ext: String) -> String {
    let cleanExt = ext.isEmpty ? "bin" : ext
    return "sigillum_shared_\(Int(Date().timeIntervalSince1970 * 1000)).\(cleanExt)"
  }

  private func extensionForType(_ type: String) -> String {
    if type == UTType.movie.identifier ||
      type == UTType.mpeg4Movie.identifier ||
      type == UTType.quickTimeMovie.identifier {
      return "mp4"
    }
    if type == UTType.jpeg.identifier || type == UTType.image.identifier {
      return "jpg"
    }
    if type == UTType.png.identifier {
      return "png"
    }
    if type == UTType.plainText.identifier {
      return "txt"
    }
    return "bin"
  }

  private func openHostAppAndFinish() {
    DispatchQueue.main.async {
      guard let url = URL(string: "\(self.urlScheme)://shared") else {
        self.finish()
        return
      }

      self.extensionContext?.open(url) { _ in
        self.finish()
      }
    }
  }

  private func finish() {
    DispatchQueue.main.async {
      self.extensionContext?.completeRequest(returningItems: nil)
    }
  }
}
