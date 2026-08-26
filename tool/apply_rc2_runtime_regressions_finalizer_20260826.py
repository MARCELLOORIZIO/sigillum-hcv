from pathlib import Path
import re

CAMERA = Path('lib/camera_page.dart')
SCENE = Path('ios/Runner/SceneDelegate.swift')
IMPORT = Path('lib/import_page.dart')


# ---------------------------------------------------------------------------
# 1) Photo HCVPACK move: if package creation already produced the final target
# path, never delete that path and then try to copy the deleted source onto
# itself. This is exactly the iOS PathNotFoundException seen in TestFlight.
# ---------------------------------------------------------------------------
camera = CAMERA.read_text(encoding='utf-8')
move_match = re.search(
    r"  Future<String> movePackageToUnifiedName\(\{.*?(?=\n  String _displayRiskMeaning\()",
    camera,
    re.S,
)
if not move_match:
    raise RuntimeError('movePackageToUnifiedName semantic region missing')
move_region = move_match.group(0)

same_path_guard = '''    if (p.normalize(currentFile.absolute.path) ==
        p.normalize(newFile.absolute.path)) {
      if (!await currentFile.exists()) {
        throw FileSystemException(
          'HCVPACK source disappeared before final naming',
          currentFile.path,
        );
      }
      return currentFile.path;
    }

'''
if 'HCVPACK source disappeared before final naming' not in move_region:
    anchor = '    final newFile = File(newPath);\n\n'
    if move_region.count(anchor) != 1:
        raise RuntimeError('HCVPACK destination file anchor not unique')
    move_region = move_region.replace(anchor, anchor + same_path_guard, 1)
    camera = camera[:move_match.start()] + move_region + camera[move_match.end():]
    CAMERA.write_text(camera, encoding='utf-8')
    print('HCVPACK same-path move guard applied')
else:
    print('HCVPACK same-path move guard already applied')


# ---------------------------------------------------------------------------
# 2) iOS original-photo picker lifecycle. The Flutter result is delivered only
# after PHPicker is fully dismissed, and pending state is cleared exactly when
# a result/error/cancel is completed. This prevents a stale or overlapping
# picker lifecycle after the first verification.
# ---------------------------------------------------------------------------
scene = SCENE.read_text(encoding='utf-8')
if 'PHPickerViewControllerDelegate' not in scene:
    raise RuntimeError('original-photo PHPicker core was not materialized')

picker_pattern = re.compile(
    r"  func picker\(_ picker: PHPickerViewController, didFinishPicking results: \[PHPickerResult\]\) \{.*?(?=\n  private func saveToPhotos\()",
    re.S,
)
picker_match = picker_pattern.search(scene)
if not picker_match:
    raise RuntimeError('PHPicker delegate semantic region missing')

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

current_picker = picker_match.group(0)
if 'private func finishOriginalPhotoPick(_ value: Any?)' not in current_picker:
    scene = scene[:picker_match.start()] + stable_picker + scene[picker_match.end():]
    SCENE.write_text(scene, encoding='utf-8')
    print('iOS PHPicker completion lifecycle stabilized')
else:
    print('iOS PHPicker completion lifecycle already stabilized')


# ---------------------------------------------------------------------------
# 3) Flutter-side re-entry guard. It prevents accidental double invocation but
# always clears in finally after a completed native call or handled error.
# ---------------------------------------------------------------------------
imp = IMPORT.read_text(encoding='utf-8')
if "invokeMethod<String>('pickOriginalPhoto')" not in imp:
    raise RuntimeError('iOS original-photo ImportPage contract not materialized')

if 'bool _photoPickBusy = false;' not in imp:
    state_anchor = "  static const _mediaChannel = MethodChannel('hcv.media');\n"
    if imp.count(state_anchor) != 1:
        raise RuntimeError('ImportPage media channel state anchor missing')
    imp = imp.replace(state_anchor, state_anchor + '  bool _photoPickBusy = false;\n', 1)

pick_pattern = re.compile(
    r"  Future<void> pickPhoto\(\) async \{.*?(?=\n  Future<void> pickVideo\(\) async \{)",
    re.S,
)
pick_match = pick_pattern.search(imp)
if not pick_match:
    raise RuntimeError('ImportPage pickPhoto semantic region missing')

stable_pick = '''  Future<void> pickPhoto() async {
    if (_photoPickBusy) return;
    if (mounted) setState(() => _photoPickBusy = true);
    try {
      String? path;
      if (Platform.isIOS) {
        path = await _mediaChannel.invokeMethod<String>('pickOriginalPhoto');
      } else {
        final file = await ImagePicker().pickImage(source: ImageSource.gallery);
        path = file?.path;
      }
      if (path == null || path.isEmpty) {
        if (mounted) setState(() => status = _t('noFileSelected'));
        return;
      }
      await _openPickedPath(path);
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() => status = "${_t('importError')}: ${e.message ?? e.code}");
      }
    } catch (e) {
      if (mounted) setState(() => status = "${_t('importError')}: $e");
    } finally {
      if (mounted) setState(() => _photoPickBusy = false);
    }
  }
'''
if 'if (_photoPickBusy) return;' not in pick_match.group(0):
    imp = imp[:pick_match.start()] + stable_pick + imp[pick_match.end():]
    IMPORT.write_text(imp, encoding='utf-8')
    print('ImportPage photo picker re-entry guard applied')
else:
    print('ImportPage photo picker re-entry guard already applied')


# Exact final assertions.
for path, tokens in {
    CAMERA: [
        'HCVPACK source disappeared before final naming',
        'p.normalize(currentFile.absolute.path)',
        'p.normalize(newFile.absolute.path)',
    ],
    SCENE: [
        'private func finishOriginalPhotoPick(_ value: Any?)',
        'picker.dismiss(animated: true) { [weak self] in',
        'self.resolveOriginalPhotoSelection(results)',
        'pendingOriginalPhotoResult = nil',
    ],
    IMPORT: [
        'bool _photoPickBusy = false;',
        'if (_photoPickBusy) return;',
        'finally {',
        'setState(() => _photoPickBusy = false)',
    ],
}.items():
    final = path.read_text(encoding='utf-8')
    for token in tokens:
        if token not in final:
            raise RuntimeError(f'RC2 runtime regression token missing in {path}: {token}')

print('RC2 runtime regressions finalizer PASS')
