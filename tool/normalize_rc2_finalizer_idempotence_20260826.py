from pathlib import Path
import re

SCENE = Path('ios/Runner/SceneDelegate.swift')
QUICK = Path('lib/quick_hcv_media_gate_page.dart')


# ---------------------------------------------------------------------------
# 1) Canonicalize the iOS original-photo PHPicker lifecycle region.
# Historical RC2 patchers can reinsert the helper methods when invoked again
# because their semantic matcher starts at func picker(...), after the helpers.
# Collapse any such repeated output to exactly one canonical implementation.
# ---------------------------------------------------------------------------
scene = SCENE.read_text(encoding='utf-8')

helper_marker = '  private func finishOriginalPhotoPick(_ value: Any?) {'
picker_marker = (
    '  func picker(_ picker: PHPickerViewController, '
    'didFinishPicking results: [PHPickerResult]) {'
)
price_method_marker = '  private func localizedProductPrices('
save_marker = '  private func saveToPhotos('
had_price_method = price_method_marker in scene

starts = [
    pos
    for pos in (scene.find(helper_marker), scene.find(picker_marker))
    if pos >= 0
]
if not starts:
    raise RuntimeError('RC2 idempotence normalizer: PHPicker lifecycle start missing')
start = min(starts)

# The native StoreKit storefront helper is intentionally inserted immediately
# after the PHPicker lifecycle and before saveToPhotos. Never absorb it into the
# PHPicker replacement region: doing so leaves the method-channel handler in
# place while deleting its Swift implementation.
ends = [
    pos
    for pos in (
        scene.find(price_method_marker, start),
        scene.find(save_marker, start),
    )
    if pos >= 0
]
if not ends:
    raise RuntimeError('RC2 idempotence normalizer: PHPicker lifecycle boundary missing')
end = min(ends)

stable_picker = r'''  private func finishOriginalPhotoPick(_ value: Any?) {
    guard let flutterResult = pendingOriginalPhotoResult else { return }
    pendingOriginalPhotoResult = nil
    flutterResult(value)
  }

  private func finishOriginalPhotoPick(error: FlutterError) {
    guard let flutterResult = pendingOriginalPhotoResult else { return }
    pendingOriginalPhotoResult = nil
    flutterResult(error)
  }

  private func resolveOriginalPhotoSelection(_ results: [PHPickerResult]) {
    guard let assetIdentifier = results.first?.assetIdentifier else {
      finishOriginalPhotoPick(nil)
      return
    }

    let assets = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
    guard let asset = assets.firstObject else {
      finishOriginalPhotoPick(error: FlutterError(
        code: "PHOTO_ASSET_NOT_FOUND",
        message: "Selected Photos asset was not found",
        details: nil
      ))
      return
    }

    let resources = PHAssetResource.assetResources(for: asset)
    let original = resources.first(where: { $0.type == .photo })
      ?? resources.first(where: { $0.type == .fullSizePhoto })
    guard let resource = original else {
      finishOriginalPhotoPick(error: FlutterError(
        code: "PHOTO_ORIGINAL_UNAVAILABLE",
        message: "Original photo bytes are unavailable",
        details: nil
      ))
      return
    }

    let rawExtension = URL(fileURLWithPath: resource.originalFilename).pathExtension
    let fileExtension = rawExtension.isEmpty ? "jpg" : rawExtension
    let output = FileManager.default.temporaryDirectory.appendingPathComponent(
      "hcv_original_\(UUID().uuidString).\(fileExtension)"
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
          self.finishOriginalPhotoPick(error: FlutterError(
            code: "PHOTO_ORIGINAL_READ_ERROR",
            message: error.localizedDescription,
            details: nil
          ))
        } else {
          self.finishOriginalPhotoPick(output.path)
        }
      }
    }
  }

  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    picker.dismiss(animated: true) { [weak self] in
      guard let self = self else { return }
      self.resolveOriginalPhotoSelection(results)
    }
  }

'''

scene = scene[:start] + stable_picker + scene[end:]

for token, expected in {
    helper_marker: 1,
    '  private func finishOriginalPhotoPick(error: FlutterError) {': 1,
    '  private func resolveOriginalPhotoSelection(_ results: [PHPickerResult]) {': 1,
    picker_marker: 1,
}.items():
    count = scene.count(token)
    if count != expected:
        raise RuntimeError(
            f'RC2 idempotence normalizer: unexpected PHPicker token count '
            f'for {token!r}: {count}'
        )

if had_price_method and price_method_marker not in scene:
    raise RuntimeError(
        'RC2 idempotence normalizer: native storefront price method was removed'
    )
if 'call.method == "localizedProductPrices"' in scene and price_method_marker not in scene:
    raise RuntimeError(
        'RC2 idempotence normalizer: storefront handler has no Swift implementation'
    )

SCENE.write_text(scene, encoding='utf-8')
print('RC2 idempotence: PHPicker lifecycle normalized to one canonical region')


# ---------------------------------------------------------------------------
# 2) Canonicalize QuickHcvMediaGatePage.initState().
# The historical localization patch blindly inserts the localized fast-check
# assignment before addPostFrameCallback every time it runs. Keep exactly one
# assignment immediately before that callback.
# ---------------------------------------------------------------------------
quick = QUICK.read_text(encoding='utf-8')
init_marker = '  void initState() {'
callback_marker = '    WidgetsBinding.instance.addPostFrameCallback((_) {'

init_start = quick.find(init_marker)
if init_start < 0:
    raise RuntimeError('RC2 idempotence normalizer: quick-gate initState missing')
callback = quick.find(callback_marker, init_start)
if callback < 0:
    raise RuntimeError('RC2 idempotence normalizer: quick-gate callback missing')

prefix = quick[init_start:callback]
prefix = re.sub(
    r"^\s*_status = _v\('fastCheck'\);\s*\n",
    '',
    prefix,
    flags=re.MULTILINE,
)
prefix = prefix.rstrip() + "\n    _status = _v('fastCheck');\n"
quick = quick[:init_start] + prefix + quick[callback:]

# Scope the assertion to initState rather than the whole file.
callback = quick.find(callback_marker, init_start)
init_prefix = quick[init_start:callback]
fast_count = init_prefix.count("_status = _v('fastCheck');")
if fast_count != 1:
    raise RuntimeError(
        'RC2 idempotence normalizer: quick-gate fastCheck assignment count '
        f'is {fast_count}, expected 1'
    )

QUICK.write_text(quick, encoding='utf-8')
print('RC2 idempotence: quick-gate fastCheck initialization normalized to one assignment')
