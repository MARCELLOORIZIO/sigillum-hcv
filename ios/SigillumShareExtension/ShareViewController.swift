import MobileCoreServices
import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
  private let sharedPathKey = "hcv.share.path"
  private var didComplete = false
  private var statusLabel: UILabel?
  private var openButton: UIButton?
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
    showLoadingState()
    handleSharedItem()
  }

  private func handleSharedItem() {
    guard
      let item = extensionContext?.inputItems.first as? NSExtensionItem,
      let providers = item.attachments
    else {
      finish()
      return
    }

    let preferredTypes = [
      UTType.movie.identifier,
      UTType.mpeg4Movie.identifier,
      UTType.quickTimeMovie.identifier,
      UTType.video.identifier,
      UTType.image.identifier,
      UTType.jpeg.identifier,
      UTType.png.identifier,
      UTType.plainText.identifier,
      UTType.fileURL.identifier,
      kUTTypeMovie as String,
      kUTTypeVideo as String,
      kUTTypeImage as String,
      kUTTypeURL as String,
    ]

    for provider in providers {
      for type in preferredTypes {
        if load(provider, type: type) {
          return
        }
      }
    }

    finish()
  }

  private func load(_ provider: NSItemProvider, type: String) -> Bool {
    guard provider.hasItemConformingToTypeIdentifier(type) else {
      return false
    }

    if isFileBackedType(type) {
      provider.loadFileRepresentation(forTypeIdentifier: type) { [weak self] url, _ in
        guard let self = self else { return }
        if let url, let destination = self.copyFileUrlToSharedContainer(url, preferredType: type) {
          self.storePathAndOpen(destination)
          return
        }

        provider.loadItem(forTypeIdentifier: type, options: nil) { [weak self] item, _ in
          self?.storeAndOpen(item, preferredType: type)
        }
      }
    } else {
      provider.loadItem(forTypeIdentifier: type, options: nil) { [weak self] item, _ in
        self?.storeAndOpen(item, preferredType: type)
      }
    }

    return true
  }

  private func isImageType(_ type: String) -> Bool {
    return type == UTType.image.identifier ||
      type == UTType.jpeg.identifier ||
      type == UTType.png.identifier ||
      type == kUTTypeImage as String
  }

  private func isFileBackedType(_ type: String) -> Bool {
    return type == UTType.movie.identifier ||
      type == UTType.mpeg4Movie.identifier ||
      type == UTType.quickTimeMovie.identifier ||
      type == UTType.video.identifier ||
      type == UTType.image.identifier ||
      type == UTType.jpeg.identifier ||
      type == UTType.png.identifier ||
      type == UTType.fileURL.identifier ||
      type == kUTTypeMovie as String ||
      type == kUTTypeVideo as String ||
      type == kUTTypeImage as String ||
      type == kUTTypeURL as String
  }

  private func storeAndOpen(_ item: NSSecureCoding?, preferredType: String) {
    guard let destination = copyToSharedContainer(item, preferredType: preferredType) else {
      finish()
      return
    }

    storePathAndOpen(destination)
  }

  private func storePathAndOpen(_ destination: URL) {
    let defaults = UserDefaults(suiteName: appGroupId)
    defaults?.set(destination.path, forKey: sharedPathKey)
    defaults?.synchronize()
    UserDefaults.standard.set(destination.path, forKey: sharedPathKey)
    UserDefaults.standard.synchronize()
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
        if isImageType(preferredType) && UIImage(contentsOfFile: url.path) == nil {
          return nil
        }
        return try copyFileUrl(url, to: inbox, preferredType: preferredType)
      }

      if let image = item as? UIImage, let data = image.jpegData(compressionQuality: 0.95) {
        let destination = inbox.appendingPathComponent(fileName(ext: "jpg"))
        try data.write(to: destination, options: .atomic)
        return destination
      }

      if let data = item as? Data {
        if isImageType(preferredType) {
          guard
            let image = UIImage(data: data),
            let normalized = image.jpegData(compressionQuality: 0.95)
          else {
            return nil
          }
          let destination = inbox.appendingPathComponent(fileName(ext: "jpg"))
          try normalized.write(to: destination, options: .atomic)
          return destination
        }
        let destination = inbox.appendingPathComponent(fileName(ext: extensionForType(preferredType)))
        try data.write(to: destination, options: .atomic)
        return destination
      }

      if let data = item as? NSData {
        let swiftData = data as Data
        if isImageType(preferredType) {
          guard
            let image = UIImage(data: swiftData),
            let normalized = image.jpegData(compressionQuality: 0.95)
          else {
            return nil
          }
          let destination = inbox.appendingPathComponent(fileName(ext: "jpg"))
          try normalized.write(to: destination, options: .atomic)
          return destination
        }
        let destination = inbox.appendingPathComponent(fileName(ext: extensionForType(preferredType)))
        try swiftData.write(to: destination, options: .atomic)
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

  private func copyFileUrlToSharedContainer(_ url: URL, preferredType: String) -> URL? {
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
      if isImageType(preferredType) && UIImage(contentsOfFile: url.path) == nil {
        return nil
      }
      return try copyFileUrl(url, to: inbox, preferredType: preferredType)
    } catch {
      return nil
    }
  }

  private func copyFileUrl(_ url: URL, to inbox: URL, preferredType: String) throws -> URL {
    let didAccess = url.startAccessingSecurityScopedResource()
    defer {
      if didAccess {
        url.stopAccessingSecurityScopedResource()
      }
    }

    let ext = url.pathExtension.isEmpty ? extensionForType(preferredType) : url.pathExtension
    let destination = inbox.appendingPathComponent(fileName(ext: ext))
    if FileManager.default.fileExists(atPath: destination.path) {
      try FileManager.default.removeItem(at: destination)
    }
    try FileManager.default.copyItem(at: url, to: destination)
    return destination
  }

  private func fileName(ext: String) -> String {
    let cleanExt = ext.isEmpty ? "bin" : ext
    return "sigillum_shared_\(Int(Date().timeIntervalSince1970 * 1000)).\(cleanExt)"
  }

  private func extensionForType(_ type: String) -> String {
    if type == UTType.movie.identifier ||
      type == UTType.mpeg4Movie.identifier ||
      type == UTType.quickTimeMovie.identifier ||
      type == UTType.video.identifier ||
      type == kUTTypeMovie as String ||
      type == kUTTypeVideo as String {
      return "mp4"
    }
    if type == UTType.jpeg.identifier ||
      type == UTType.image.identifier ||
      type == kUTTypeImage as String {
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

  private func showLoadingState() {
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.text = "Preparazione contenuto..."
    label.textAlignment = .center
    label.numberOfLines = 0
    label.font = .preferredFont(forTextStyle: .headline)
    view.addSubview(label)
    statusLabel = label

    let button = UIButton(type: .system)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.setTitle("CHIUDI", for: .normal)
    button.titleLabel?.font = .preferredFont(forTextStyle: .headline)
    button.backgroundColor = UIColor.systemTeal.withAlphaComponent(0.16)
    button.layer.cornerRadius = 18
    button.contentEdgeInsets = UIEdgeInsets(top: 16, left: 22, bottom: 16, right: 22)
    button.isHidden = true
    button.addTarget(self, action: #selector(openButtonTapped), for: .touchUpInside)
    view.addSubview(button)
    openButton = button

    NSLayoutConstraint.activate([
      label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
      label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
      label.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -36),
      button.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 24),
      button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
    ])
  }

  private func openHostAppAndFinish() {
    DispatchQueue.main.async {
      self.statusLabel?.text =
        "Contenuto salvato in Fotocamera Sigillum.\nTocca CHIUDI, poi apri Fotocamera Sigillum: la verifica partirà automaticamente."
      self.openButton?.setTitle("CHIUDI", for: .normal)
      self.openButton?.isHidden = false
      self.openButton?.isEnabled = true
    }
  }

  @objc private func openButtonTapped() {
    finish()
  }

  private func showOpenFailed() {
    statusLabel?.text =
      "Contenuto salvato in Fotocamera Sigillum.\nTocca CHIUDI, poi apri Fotocamera Sigillum: la verifica partirà automaticamente."
    openButton?.setTitle("CHIUDI", for: .normal)
    openButton?.isHidden = false
    openButton?.isEnabled = true
  }

  private func finish() {
    DispatchQueue.main.async {
      if self.didComplete {
        return
      }
      self.didComplete = true
      self.extensionContext?.completeRequest(returningItems: nil)
    }
  }
}
