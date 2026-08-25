from pathlib import Path

PACKAGE = Path('lib/hcv_package.dart')
PLAYER = Path('lib/hcvpack_player_page.dart')
IMPORT = Path('lib/import_page.dart')
SCENE = Path('ios/Runner/SceneDelegate.swift')


def require_once(source: str, old: str, new: str, label: str) -> str:
    if new in source:
        print(f'{label}: already applied')
        return source
    count = source.count(old)
    if count != 1:
        raise RuntimeError(f'{label}: expected one legacy anchor, got {count}')
    print(f'{label}: applied')
    return source.replace(old, new, 1)


# ---------------------------------------------------------------------------
# HCVPACK v3 photo schema. Keep v2 video creation untouched for compatibility.
# ---------------------------------------------------------------------------
package = PACKAGE.read_text(encoding='utf-8')

photo_method = r'''
  Future<String> createPhotoPackage({
    required String photoPath,
    required String hcvPath,
  }) async {
    final photoFile = File(photoPath);
    final hcvFile = File(hcvPath);

    if (!await photoFile.exists()) {
      throw Exception('Photo file does not exist');
    }
    if (!await hcvFile.exists()) {
      throw Exception('HCV file does not exist');
    }

    final photoBytes = await photoFile.readAsBytes();
    final hcvBytes = await hcvFile.readAsBytes();
    final contentSha256 = sha256.convert(photoBytes).toString();
    final certificateSha256 = sha256.convert(hcvBytes).toString();
    final createdAt = DateTime.now().toUtc().toIso8601String();
    final originalName = p.basename(photoPath);
    final extension = p.extension(originalName).toLowerCase();
    final safeExtension = extension == '.png' ? '.png' : '.jpg';
    final contentFile = 'photo$safeExtension';

    final packageIdSource =
        '$contentSha256|$certificateSha256|$createdAt';
    final packageId =
        sha256.convert(utf8.encode(packageIdSource)).toString();

    final meta = <String, dynamic>{
      'type': 'HCV_PACKAGE',
      'version': 3,
      'mediaType': 'photo',
      'contentFile': contentFile,
      'certificateFile': 'certificate.hcv',
      'originalContentName': originalName,
      'contentSha256': contentSha256,
      'certificateSha256': certificateSha256,
      'hashAlgorithm': 'SHA256',
      'certificateFormat': 'HCV',
      'createdAt': createdAt,
      'packageId': packageId,
    };

    final archive = Archive();
    archive.addFile(ArchiveFile(contentFile, photoBytes.length, photoBytes));
    archive.addFile(
      ArchiveFile('certificate.hcv', hcvBytes.length, hcvBytes),
    );
    final metaBytes = utf8.encode(jsonEncode(meta));
    archive.addFile(ArchiveFile('meta.json', metaBytes.length, metaBytes));

    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes == null) {
      throw Exception('Unable to create HCV photo package');
    }

    final outputDir = await getApplicationDocumentsDirectory();
    final base = p.basenameWithoutExtension(photoPath);
    final output = File(p.join(outputDir.path, '$base.hcvpack'));
    await output.writeAsBytes(zipBytes, flush: true);
    return output.path;
  }
'''

if 'Future<String> createPhotoPackage({' not in package:
    close = package.rfind('\n}')
    if close < 0:
        raise RuntimeError('HCVPackage class closing anchor missing')
    package = package[:close] + photo_method + package[close:]

for token in [
    'Future<String> createPhotoPackage({',
    "'version': 3",
    "'mediaType': 'photo'",
    "'contentFile': contentFile",
    "'contentSha256': contentSha256",
    "ArchiveFile(contentFile, photoBytes.length, photoBytes)",
]:
    if token not in package:
        raise RuntimeError(f'photo HCVPACK v3 contract missing: {token}')
PACKAGE.write_text(package, encoding='utf-8')


# ---------------------------------------------------------------------------
# Reader: accept legacy v2 video-shaped packages and neutral v3 packages.
# ---------------------------------------------------------------------------
player = PLAYER.read_text(encoding='utf-8')

old_entries = '''      ArchiveFile? videoEntry;
      ArchiveFile? certEntry;
      ArchiveFile? metaEntry;

      for (final entry in archive.files) {
        final name = entry.name.toLowerCase();

        if (name == "video.mp4") {
          videoEntry = entry;
        }

        if (name == "certificate.hcv") {
          certEntry = entry;
        }

        if (name == "meta.json") {
          metaEntry = entry;
        }
      }

      if (videoEntry == null || certEntry == null || metaEntry == null) {
'''
new_entries = '''      ArchiveFile? certEntry;
      ArchiveFile? metaEntry;

      for (final entry in archive.files) {
        final name = entry.name.toLowerCase();
        if (name == "certificate.hcv") certEntry = entry;
        if (name == "meta.json") metaEntry = entry;
      }

      if (certEntry == null || metaEntry == null) {
'''
player = require_once(player, old_entries, new_entries, 'neutral HCVPACK entry discovery')

old_bytes = '''      final videoBytes = List<int>.from(videoEntry.content as List<int>);
      final certBytes = List<int>.from(certEntry.content as List<int>);
      final metaBytes = List<int>.from(metaEntry.content as List<int>);

      final certSha256 = sha256.convert(certBytes).toString();
      final videoSha256 = sha256.convert(videoBytes).toString();

      final metaStr = utf8.decode(metaBytes);
      final metaJson = jsonDecode(metaStr);

      if (metaJson is! Map<String, dynamic>) {
'''
new_bytes = '''      final certBytes = List<int>.from(certEntry.content as List<int>);
      final metaBytes = List<int>.from(metaEntry.content as List<int>);
      final certSha256 = sha256.convert(certBytes).toString();
      final metaStr = utf8.decode(metaBytes);
      final metaJson = jsonDecode(metaStr);

      if (metaJson is! Map<String, dynamic>) {
'''
player = require_once(player, old_bytes, new_bytes, 'neutral HCVPACK metadata read')

old_meta_call = '''      final metaOk = _validateMeta(
        meta: metaJson,
        videoSha256: videoSha256,
        certificateSha256: certSha256,
      );

      if (!metaOk) {
        final tempVideoFile = await _writeTempContent(videoBytes, 'bin');
'''
new_meta_call = '''      final packageVersion = (metaJson["version"] as num?)?.toInt();
      final contentFileName = packageVersion == 3
          ? metaJson["contentFile"]?.toString()
          : metaJson["videoFile"]?.toString();
      ArchiveFile? contentEntry;
      if (contentFileName != null && contentFileName.isNotEmpty) {
        for (final entry in archive.files) {
          if (entry.name == contentFileName) {
            contentEntry = entry;
            break;
          }
        }
      }
      if (contentEntry == null) {
        setState(() {
          loading = false;
          status = "HCVPACK ZIP incompleto: contenuto mancante";
          result = "ERROR";
        });
        return;
      }
      final contentBytes = List<int>.from(contentEntry.content as List<int>);
      final contentSha256 = sha256.convert(contentBytes).toString();

      final metaOk = _validateMeta(
        meta: metaJson,
        contentSha256: contentSha256,
        certificateSha256: certSha256,
      );

      if (!metaOk) {
        final tempVideoFile = await _writeTempContent(contentBytes, 'bin');
'''
player = require_once(player, old_meta_call, new_meta_call, 'versioned HCVPACK content resolution')

player = player.replace(
    '        videoBytes: videoBytes,\n        certificate: certificate,',
    '        videoBytes: contentBytes,\n        certificate: certificate,',
    1,
)

old_validator = '''  bool _validateMeta({
    required Map<String, dynamic> meta,
    required String videoSha256,
    required String certificateSha256,
  }) {
    if (meta["type"] != "HCV_PACKAGE") return false;
    if (meta["version"] != 2) return false;

    if (meta["videoFile"] != "video.mp4") return false;
    if (meta["certificateFile"] != "certificate.hcv") return false;

    if (meta["hashAlgorithm"] != "SHA256") return false;
    if (meta["certificateFormat"] != "HCV") return false;

    if (meta["videoSha256"] != videoSha256) return false;
    if (meta["certificateSha256"] != certificateSha256) return false;

    final packageId = meta["packageId"];
    final createdAt = meta["createdAt"];

    if (packageId == null || packageId is! String || packageId.isEmpty) {
      return false;
    }

    if (createdAt == null || createdAt is! String || createdAt.isEmpty) {
      return false;
    }

    final expectedPackageIdSource =
        "$videoSha256|$certificateSha256|$createdAt";
    final expectedPackageId =
        sha256.convert(utf8.encode(expectedPackageIdSource)).toString();

    if (packageId != expectedPackageId) return false;

    return true;
  }
'''
new_validator = '''  bool _validateMeta({
    required Map<String, dynamic> meta,
    required String contentSha256,
    required String certificateSha256,
  }) {
    if (meta["type"] != "HCV_PACKAGE") return false;
    final version = (meta["version"] as num?)?.toInt();
    if (version != 2 && version != 3) return false;
    if (meta["certificateFile"] != "certificate.hcv") return false;
    if (meta["hashAlgorithm"] != "SHA256") return false;
    if (meta["certificateFormat"] != "HCV") return false;
    if (meta["certificateSha256"] != certificateSha256) return false;

    if (version == 2) {
      if (meta["videoFile"] != "video.mp4") return false;
      if (meta["videoSha256"] != contentSha256) return false;
    } else {
      if (meta["mediaType"] != "photo") return false;
      final contentFile = meta["contentFile"]?.toString() ?? '';
      if (!contentFile.startsWith('photo.')) return false;
      if (meta["contentSha256"] != contentSha256) return false;
    }

    final packageId = meta["packageId"];
    final createdAt = meta["createdAt"];
    if (packageId is! String || packageId.isEmpty) return false;
    if (createdAt is! String || createdAt.isEmpty) return false;

    final expectedPackageIdSource =
        "$contentSha256|$certificateSha256|$createdAt";
    final expectedPackageId =
        sha256.convert(utf8.encode(expectedPackageIdSource)).toString();
    return packageId == expectedPackageId;
  }
'''
player = require_once(player, old_validator, new_validator, 'HCVPACK v2/v3 meta validator')

for token in [
    'version != 2 && version != 3',
    'meta["contentSha256"] != contentSha256',
    "contentFile.startsWith('photo.')",
]:
    if token not in player:
        raise RuntimeError(f'HCVPACK reader compatibility contract missing: {token}')
PLAYER.write_text(player, encoding='utf-8')


# ---------------------------------------------------------------------------
# iOS: native PHPicker + PHAssetResourceManager exact resource extraction.
# ---------------------------------------------------------------------------
scene = SCENE.read_text(encoding='utf-8')
if 'import PhotosUI' not in scene:
    scene = scene.replace('import Photos\n', 'import Photos\nimport PhotosUI\n', 1)

scene = scene.replace(
    'class SceneDelegate: FlutterSceneDelegate {',
    'class SceneDelegate: FlutterSceneDelegate, PHPickerViewControllerDelegate {',
    1,
)

if 'private var pendingOriginalPhotoResult: FlutterResult?' not in scene:
    scene = scene.replace(
        '  private var mediaChannel: FlutterMethodChannel?\n',
        '  private var mediaChannel: FlutterMethodChannel?\n'
        '  private var pendingOriginalPhotoResult: FlutterResult?\n',
        1,
    )

old_dispatch = '''      } else if call.method == "extractVideoFrame" {
'''
new_dispatch = '''      } else if call.method == "pickOriginalPhoto" {
        self.pickOriginalPhoto(result: result)
      } else if call.method == "extractVideoFrame" {
'''
scene = require_once(scene, old_dispatch, new_dispatch, 'native original-photo media method')

native_methods = r'''

  private func pickOriginalPhoto(result: @escaping FlutterResult) {
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

  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    picker.dismiss(animated: true)
    guard let flutterResult = pendingOriginalPhotoResult else { return }
    pendingOriginalPhotoResult = nil

    guard let assetIdentifier = results.first?.assetIdentifier else {
      flutterResult(nil)
      return
    }
    let assets = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
    guard let asset = assets.firstObject else {
      flutterResult(FlutterError(
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
      flutterResult(FlutterError(
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
    let options = PHAssetResourceRequestOptions()
    options.isNetworkAccessAllowed = true
    PHAssetResourceManager.default().writeData(
      for: resource,
      toFile: output,
      options: options
    ) { error in
      DispatchQueue.main.async {
        if let error = error {
          flutterResult(FlutterError(
            code: "PHOTO_ORIGINAL_READ_ERROR",
            message: error.localizedDescription,
            details: nil
          ))
        } else {
          flutterResult(output.path)
        }
      }
    }
  }
'''

if 'private func pickOriginalPhoto(result:' not in scene:
    anchor = '\n  private func saveToPhotos(path: String, result: @escaping FlutterResult) {'
    if anchor not in scene:
        raise RuntimeError('SceneDelegate media-method insertion anchor missing')
    scene = scene.replace(anchor, native_methods + anchor, 1)

for token in [
    'PHPickerViewControllerDelegate',
    'call.method == "pickOriginalPhoto"',
    'PHAssetResource.assetResources(for: asset)',
    'PHAssetResourceManager.default().writeData(',
    'options.isNetworkAccessAllowed = true',
]:
    if token not in scene:
        raise RuntimeError(f'iOS original-photo contract missing: {token}')
SCENE.write_text(scene, encoding='utf-8')


# ---------------------------------------------------------------------------
# Flutter photo picker: use exact native resource on iOS, ImagePicker elsewhere.
# ---------------------------------------------------------------------------
imp = IMPORT.read_text(encoding='utf-8')
if "import 'dart:io';" not in imp:
    imp = "import 'dart:io';\n\n" + imp
if "import 'package:flutter/services.dart';" not in imp:
    imp = imp.replace(
        "import 'package:flutter/material.dart';\n",
        "import 'package:flutter/material.dart';\nimport 'package:flutter/services.dart';\n",
        1,
    )
if "static const _mediaChannel = MethodChannel('hcv.media');" not in imp:
    imp = imp.replace(
        'class _ImportPageState extends State<ImportPage> {\n',
        "class _ImportPageState extends State<ImportPage> {\n"
        "  static const _mediaChannel = MethodChannel('hcv.media');\n",
        1,
    )

old_pick = '''  Future<void> pickPhoto() async {
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (file == null) {
        if (mounted) setState(() => status = _t('noFileSelected'));
        return;
      }
      await _openPickedPath(file.path);
    } catch (e) {
      if (mounted) setState(() => status = "${_t('importError')}: $e");
    }
  }
'''
new_pick = '''  Future<void> pickPhoto() async {
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
    }
  }
'''
imp = require_once(imp, old_pick, new_pick, 'iOS exact-original verification picker')
for token in [
    "MethodChannel('hcv.media')",
    'Platform.isIOS',
    "invokeMethod<String>('pickOriginalPhoto')",
]:
    if token not in imp:
        raise RuntimeError(f'Flutter exact-original picker contract missing: {token}')
IMPORT.write_text(imp, encoding='utf-8')


print('RC2 photo original-byte picker and HCVPACK v3 integrity finalizer PASS')
