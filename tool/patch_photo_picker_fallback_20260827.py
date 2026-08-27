from pathlib import Path

path = Path('ios/Runner/SceneDelegate.swift')
text = path.read_text(encoding='utf-8')

if 'import UniformTypeIdentifiers\n' not in text:
    text = text.replace('import PhotosUI\n', 'import PhotosUI\nimport UniformTypeIdentifiers\n', 1)

old_pick = '''  private func pickOriginalPhoto(result: @escaping FlutterResult) {
    guard pendingOriginalPhotoResult == nil else {
      result(FlutterError(
        code: "PHOTO_PICK_BUSY",
        message: "Another original-photo selection is already active",
        details: nil
      ))
      return
    }

    PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
      guard status == .authorized || status == .limited else {
        DispatchQueue.main.async { result(nil) }
        return
      }
      DispatchQueue.main.async {
        guard let presenter = self.window?.rootViewController else {
          result(FlutterError(
            code: "PHOTO_PICK_NO_PRESENTER",
            message: "Unable to present Photos picker",
            details: nil
          ))
          return
        }
        self.pendingOriginalPhotoResult = result
        var configuration = PHPickerConfiguration(photoLibrary: PHPhotoLibrary.shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        configuration.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        presenter.present(picker, animated: true)
      }
    }
  }
'''

new_pick = '''  private func pickOriginalPhoto(result: @escaping FlutterResult) {
    guard pendingOriginalPhotoResult == nil else {
      result(FlutterError(
        code: "PHOTO_PICK_BUSY",
        message: "Another original-photo selection is already active",
        details: nil
      ))
      return
    }

    // PHPicker grants access to the item explicitly chosen by the user and
    // must remain usable even when Photos permission is LIMITED or DENIED.
    // If full PHAsset access is available, resolution below still prefers the
    // original PHAssetResource bytes for exact SIGILLUM hash verification.
    guard let presenter = self.window?.rootViewController else {
      result(FlutterError(
        code: "PHOTO_PICK_NO_PRESENTER",
        message: "Unable to present Photos picker",
        details: nil
      ))
      return
    }
    pendingOriginalPhotoResult = result
    var configuration = PHPickerConfiguration(photoLibrary: PHPhotoLibrary.shared())
    configuration.filter = .images
    configuration.selectionLimit = 1
    configuration.preferredAssetRepresentationMode = .current
    let picker = PHPickerViewController(configuration: configuration)
    picker.delegate = self
    presenter.present(picker, animated: true)
  }
'''

if old_pick not in text:
    raise SystemExit('pickOriginalPhoto anchor not found')
text = text.replace(old_pick, new_pick, 1)

start = text.index('  private func resolveOriginalPhotoSelection(_ results: [PHPickerResult]) {')
end = text.index('\n  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {', start)

new_resolve = '''  private func copyPickerPhotoRepresentation(
    _ selection: PHPickerResult,
    originalError: FlutterError? = nil
  ) {
    let provider = selection.itemProvider
    guard provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) else {
      finishOriginalPhotoPick(error: originalError ?? FlutterError(
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
          self.finishOriginalPhotoPick(error: originalError ?? FlutterError(
            code: "PHOTO_PICKER_FILE_ERROR",
            message: error?.localizedDescription ?? "Unable to read selected photo",
            details: nil
          ))
        }
        return
      }

      let rawExtension = source.pathExtension
      let fileExtension = rawExtension.isEmpty ? "jpg" : rawExtension
      let output = FileManager.default.temporaryDirectory.appendingPathComponent(
        "hcv_picker_\\(UUID().uuidString).\\(fileExtension)"
      )

      do {
        try? FileManager.default.removeItem(at: output)
        try FileManager.default.copyItem(at: source, to: output)
        DispatchQueue.main.async {
          self.finishOriginalPhotoPick(output.path)
        }
      } catch {
        DispatchQueue.main.async {
          self.finishOriginalPhotoPick(error: originalError ?? FlutterError(
            code: "PHOTO_PICKER_FILE_ERROR",
            message: error.localizedDescription,
            details: nil
          ))
        }
      }
    }
  }

  private func resolveOriginalPhotoSelection(_ results: [PHPickerResult]) {
    guard let selection = results.first else {
      finishOriginalPhotoPick(nil)
      return
    }

    // Exact original bytes remain the first choice whenever the selected item
    // is visible through PhotoKit. Under LIMITED Photos access PHPicker can
    // legitimately return a user-selected item that PHAsset.fetchAssets cannot
    // query; in that case fall back to the file representation granted by the
    // picker instead of rejecting the photo.
    guard let assetIdentifier = selection.assetIdentifier else {
      copyPickerPhotoRepresentation(selection)
      return
    }

    let assets = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
    guard let asset = assets.firstObject else {
      copyPickerPhotoRepresentation(selection)
      return
    }

    let resources = PHAssetResource.assetResources(for: asset)
    let original = resources.first(where: { $0.type == .photo })
      ?? resources.first(where: { $0.type == .fullSizePhoto })
    guard let resource = original else {
      copyPickerPhotoRepresentation(selection)
      return
    }

    let rawExtension = URL(fileURLWithPath: resource.originalFilename).pathExtension
    let fileExtension = rawExtension.isEmpty ? "jpg" : rawExtension
    let output = FileManager.default.temporaryDirectory.appendingPathComponent(
      "hcv_original_\\(UUID().uuidString).\\(fileExtension)"
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
            originalError: FlutterError(
              code: "PHOTO_ORIGINAL_READ_ERROR",
              message: error.localizedDescription,
              details: nil
            )
          )
        } else {
          self.finishOriginalPhotoPick(output.path)
        }
      }
    }
  }
'''

text = text[:start] + new_resolve + text[end:]

if 'Selected Photos asset was not found' in text:
    raise SystemExit('legacy PHOTO_ASSET_NOT_FOUND path still present')
if 'copyPickerPhotoRepresentation(selection)' not in text:
    raise SystemExit('fallback was not materialized')

path.write_text(text, encoding='utf-8')
print('PHOTO_PICKER_FALLBACK_MATERIALIZED=PASS')
