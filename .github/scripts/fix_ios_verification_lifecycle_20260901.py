from pathlib import Path


def replace_once(path: str, old: str, new: str, marker: str | None = None) -> None:
    file = Path(path)
    text = file.read_text()
    if marker is not None and marker in text:
        return
    if old not in text:
        raise SystemExit(f"Patch anchor not found in {path}: {old[:100]!r}")
    file.write_text(text.replace(old, new, 1))


# PHOTO quick precheck: one full OCR plus one focused top-crop OCR only.
ocr_path = Path("lib/hcv_media_id_ocr.dart")
ocr = ocr_path.read_text()
if "static Future<String?> extractFocusedFromImage" not in ocr:
    anchor = "  /// Returns every valid still-image HCV-ID candidate, ranked by independent\n"
    method = """  /// Bounded still-image fallback for the public PHOTO precheck.
  ///
  /// The fast pass has already inspected the full image. This method performs
  /// exactly one additional OCR reading on an enlarged top crop, where the
  /// visible SIGILLUM HCV-ID watermark is rendered. Full multi-crop consensus
  /// remains reserved for deeper Registry recovery.
  static Future<String?> extractFocusedFromImage(String path) async {
    final source = File(path);
    if (!await source.exists()) return null;

    File? candidate;
    try {
      final bytes = await source.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null || decoded.width < 32 || decoded.height < 32) {
        return null;
      }

      final cropHeight = max(
        32,
        min(decoded.height, (decoded.height * 0.28).round()),
      );
      final cropWidth = max(32, (decoded.width * 0.98).round());
      final cropped = img.copyCrop(
        decoded,
        x: 0,
        y: 0,
        width: cropWidth,
        height: cropHeight,
      );
      final targetWidth = min(2000, max(1000, cropped.width * 3));
      final targetHeight = max(
        120,
        (cropped.height * targetWidth / cropped.width).round(),
      );
      final enlarged = img.copyResize(
        cropped,
        width: targetWidth,
        height: targetHeight,
        interpolation: img.Interpolation.cubic,
      );

      final tempDir = await getTemporaryDirectory();
      candidate = File(
        p.join(
          tempDir.path,
          'hcv_id_ocr_focused_${DateTime.now().microsecondsSinceEpoch}.png',
        ),
      );
      await candidate.writeAsBytes(img.encodePng(enlarged), flush: true);
      return await _recognizePath(candidate.path);
    } catch (_) {
      return null;
    } finally {
      try {
        if (candidate != null && await candidate.exists()) {
          await candidate.delete();
        }
      } catch (_) {}
    }
  }

"""
    if anchor not in ocr:
        raise SystemExit("Focused OCR insertion anchor not found")
    ocr_path.write_text(ocr.replace(anchor, method + anchor, 1))

replace_once(
    "lib/quick_hcv_media_gate_page.dart",
    """  Future<String?> _ocrImage(
    String sourcePath, {
    bool allowRobustFallback = false,
  }) async {
    final fast = await HCVMediaIdOcr.extractFastFromImage(sourcePath);
    if (fast != null || !allowRobustFallback) return fast;
    return HCVMediaIdOcr.extractFromImage(sourcePath);
  }
""",
    """  Future<String?> _ocrImage(
    String sourcePath, {
    bool allowFocusedFallback = false,
  }) async {
    final fast = await HCVMediaIdOcr.extractFastFromImage(sourcePath);
    if (fast != null || !allowFocusedFallback) return fast;
    return HCVMediaIdOcr.extractFocusedFromImage(sourcePath);
  }
""",
    marker="allowFocusedFallback = false",
)
replace_once(
    "lib/quick_hcv_media_gate_page.dart",
    """        // A single native OCR miss must not classify a certified photo as
        // uncertified. Still images get one bounded robust fallback; video
        // remains on its one-frame fast path to protect startup latency.
        detectedId = await _ocrImage(widget.path, allowRobustFallback: true);
""",
    """        // A single native OCR miss must not classify a certified photo as
        // uncertified. Still images get one focused top-crop fallback only;
        // the full multi-crop consensus remains a deeper Registry recovery.
        detectedId = await _ocrImage(widget.path, allowFocusedFallback: true);
""",
    marker="allowFocusedFallback: true",
)

# Pass the HCV-ID already found by the quick gate to Registry verification.
replace_once(
    "lib/registry_verify_page.dart",
    """class RegistryVerifyPage extends StatefulWidget {
  final String? initialMediaPath;
  final String languageCode;

  const RegistryVerifyPage({
    super.key,
    this.initialMediaPath,
    this.languageCode = 'it',
  });
""",
    """class RegistryVerifyPage extends StatefulWidget {
  final String? initialMediaPath;
  final String? initialHcvId;
  final String languageCode;

  const RegistryVerifyPage({
    super.key,
    this.initialMediaPath,
    this.initialHcvId,
    this.languageCode = 'it',
  });
""",
    marker="final String? initialHcvId;",
)
replace_once(
    "lib/registry_verify_page.dart",
    """      final detectedId = await detectHcvIdFromMediaPath(path);

      if (!mounted) return;
""",
    """      final suppliedId = widget.initialHcvId?.trim().toUpperCase();
      final detectedId = suppliedId != null &&
              RegExp(r'^HCV-[A-F0-9]{16}$').hasMatch(suppliedId)
          ? suppliedId
          : await detectHcvIdFromMediaPath(path);

      if (!mounted) return;
""",
    marker="final suppliedId = widget.initialHcvId?.trim().toUpperCase();",
)
replace_once(
    "lib/quick_hcv_media_gate_page.dart",
    """        builder: (_) => RegistryVerifyPage(
          initialMediaPath: widget.path,
          languageCode: widget.languageCode,
        ),
""",
    """        builder: (_) => RegistryVerifyPage(
          initialMediaPath: widget.path,
          initialHcvId: detectedId,
          languageCode: widget.languageCode,
        ),
""",
    marker="initialHcvId: detectedId,",
)

# Shared media cold-start: queue navigation until Flutter has rendered a frame,
# deduplicate native event/getSharedPath delivery, and enter the quick router.
home_path = Path("lib/user_home_page.dart")
home = home_path.read_text()
if "import 'registry_verify_page.dart';\n" in home:
    home = home.replace("import 'registry_verify_page.dart';\n", "", 1)
if "bool _sharedOpenScheduled = false;" not in home:
    old = """  String? _lastOpenedSharedPath;
  String languageCode = SigillumCopy.initialLanguageCode();
"""
    new = """  String? _lastOpenedSharedPath;
  String? _pendingSharedPath;
  bool _sharedOpenScheduled = false;
  String languageCode = SigillumCopy.initialLanguageCode();
"""
    if old not in home:
        raise SystemExit("Shared queue field anchor not found")
    home = home.replace(old, new, 1)
home = home.replace("_openImportedPath(path);", "_queueImportedPath(path);", 2)
if "void _queueImportedPath(String path)" not in home:
    old = """  void _openImportedPath(String path) {
    if (!mounted || path.isEmpty || _lastOpenedSharedPath == path) return;
    _lastOpenedSharedPath = path;

    final lower = path.toLowerCase();
    if (lower.endsWith('.txt')) {
      File(path)
          .readAsString()
          .then((sharedText) {
            if (!mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TextSocialVerifyPage(
                  languageCode: languageCode,
                  initialText: sharedText,
                ),
              ),
            );
          })
          .catchError((_) {});
      return;
    }
    final isMedia =
        lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.txt') ||
        lower.endsWith('.pdf') ||
        lower.endsWith('.mp3') ||
        lower.endsWith('.wav');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => isMedia
            ? RegistryVerifyPage(
                initialMediaPath: path,
                languageCode: languageCode,
              )
            : HCVImportRouterPage(path: path, languageCode: languageCode),
      ),
    );
  }
"""
    new = """  void _queueImportedPath(String path) {
    if (!mounted ||
        path.isEmpty ||
        _lastOpenedSharedPath == path ||
        _pendingSharedPath == path) {
      return;
    }

    _pendingSharedPath = path;
    if (_sharedOpenScheduled) return;
    _sharedOpenScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sharedOpenScheduled = false;
      if (!mounted) return;
      final pending = _pendingSharedPath;
      _pendingSharedPath = null;
      if (pending != null && pending.isNotEmpty) {
        _openImportedPath(pending);
      }
    });
  }

  Future<void> _openImportedPath(String path) async {
    if (!mounted || path.isEmpty || _lastOpenedSharedPath == path) return;
    if (!await File(path).exists()) return;
    if (!mounted) return;
    _lastOpenedSharedPath = path;

    final lower = path.toLowerCase();
    if (lower.endsWith('.txt')) {
      try {
        final sharedText = await File(path).readAsString();
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TextSocialVerifyPage(
              languageCode: languageCode,
              initialText: sharedText,
            ),
          ),
        );
      } catch (_) {}
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HCVImportRouterPage(
          path: path,
          languageCode: languageCode,
        ),
      ),
    );
  }
"""
    if old not in home:
        raise SystemExit("Shared import routing block not found")
    home = home.replace(old, new, 1)
home_path.write_text(home)

# Native PHOTO picker lifecycle: take and clear global pending result as soon as
# PHPicker returns; async original-byte resolution gets its own callback.
scene_path = Path("ios/Runner/SceneDelegate.swift")
scene = scene_path.read_text()
if "private func takePendingOriginalPhotoResult()" not in scene:
    old = """  private func pickOriginalPhoto(result: @escaping FlutterResult) {
    guard pendingOriginalPhotoResult == nil else {
      result(FlutterError(
        code: \"PHOTO_PICK_BUSY\",
        message: \"Another original-photo selection is already active\",
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
        code: \"PHOTO_PICK_NO_PRESENTER\",
        message: \"Unable to present Photos picker\",
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

  private func finishOriginalPhotoPick(_ value: Any?) {
    guard let flutterResult = pendingOriginalPhotoResult else { return }
    pendingOriginalPhotoResult = nil
    flutterResult(value)
  }

  private func finishOriginalPhotoPick(error: FlutterError) {
    guard let flutterResult = pendingOriginalPhotoResult else { return }
    pendingOriginalPhotoResult = nil
    flutterResult(error)
  }
"""
    new = """  private func pickOriginalPhoto(result: @escaping FlutterResult) {
    guard let presenter = self.window?.rootViewController else {
      result(FlutterError(
        code: \"PHOTO_PICK_NO_PRESENTER\",
        message: \"Unable to present Photos picker\",
        details: nil
      ))
      return
    }

    if let staleResult = pendingOriginalPhotoResult {
      if presenter.presentedViewController is PHPickerViewController {
        result(FlutterError(
          code: \"PHOTO_PICK_BUSY\",
          message: \"Another original-photo selection is already active\",
          details: nil
        ))
        return
      }
      pendingOriginalPhotoResult = nil
      staleResult(FlutterError(
        code: \"PHOTO_PICK_STALE_RESET\",
        message: \"A stale photo selection was reset\",
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
"""
    if old not in scene:
        raise SystemExit("Native photo picker lifecycle block not found")
    scene = scene.replace(old, new, 1)

    scene = scene.replace(
        """  private func copyPickerPhotoRepresentation(
    _ selection: PHPickerResult,
    originalError: FlutterError? = nil
  ) {
""",
        """  private func copyPickerPhotoRepresentation(
    _ selection: PHPickerResult,
    result: @escaping FlutterResult,
    originalError: FlutterError? = nil
  ) {
""",
        1,
    )
    scene = scene.replace("finishOriginalPhotoPick(error: originalError ?? FlutterError(", "result(originalError ?? FlutterError(", 1)
    scene = scene.replace("self.finishOriginalPhotoPick(error: originalError ?? FlutterError(", "result(originalError ?? FlutterError(", 2)
    scene = scene.replace("self.finishOriginalPhotoPick(output.path)", "result(output.path)", 1)

    scene = scene.replace(
        """  private func resolveOriginalPhotoSelection(_ results: [PHPickerResult]) {
    guard let selection = results.first else {
      finishOriginalPhotoPick(nil)
      return
    }
""",
        """  private func resolveOriginalPhotoSelection(
    _ results: [PHPickerResult],
    result: @escaping FlutterResult
  ) {
    guard let selection = results.first else {
      result(nil)
      return
    }
""",
        1,
    )
    scene = scene.replace("copyPickerPhotoRepresentation(selection)\n      return", "copyPickerPhotoRepresentation(selection, result: result)\n      return", 3)
    scene = scene.replace(
        """          self.copyPickerPhotoRepresentation(
            selection,
            originalError: FlutterError(
""",
        """          self.copyPickerPhotoRepresentation(
            selection,
            result: result,
            originalError: FlutterError(
""",
        1,
    )
    scene = scene.replace("self.finishOriginalPhotoPick(output.path)", "result(output.path)", 1)
    scene = scene.replace(
        """  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    picker.dismiss(animated: true) { [weak self] in
      guard let self = self else { return }
      self.resolveOriginalPhotoSelection(results)
    }
  }
""",
        """  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
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
""",
        1,
    )
    scene_path.write_text(scene)

# Existing picker contract uses the helper after pickOriginalPhoto as its block end.
test_path = Path("test/ios_photo_picker_limited_access_fallback_contract_test.dart")
test_text = test_path.read_text()
test_text = test_text.replace(
    "'private func finishOriginalPhotoPick(_ value: Any?)'",
    "'private func takePendingOriginalPhotoResult() -> FlutterResult?'",
)
test_path.write_text(test_text)
