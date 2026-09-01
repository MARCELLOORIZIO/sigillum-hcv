from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f'missing pattern: {label}')
    return text.replace(old, new, 1)

# Dart OCR preflight before google_mlkit_text_recognition touches the path.
p = Path('lib/hcv_media_id_ocr.dart')
s = p.read_text()
s = replace_once(
    s,
    "import 'dart:math';\n\nimport 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';",
    "import 'dart:math';\n\nimport 'package:flutter/services.dart';\nimport 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';",
    'flutter services import',
)
s = replace_once(
    s,
    "class HCVMediaIdOcr {\n  const HCVMediaIdOcr._();\n",
    "class HCVMediaIdOcr {\n  const HCVMediaIdOcr._();\n\n  static const MethodChannel _mediaChannel = MethodChannel('hcv.media');\n",
    'media channel',
)
old = """  static Future<String?> _recognizePath(String path) async {\n    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);\n    try {\n      final recognized = await recognizer.processImage(\n        InputImage.fromFilePath(path),\n      );\n      return extractFromRecognizedText(recognized.text);\n    } catch (_) {\n      return null;\n    } finally {\n      await recognizer.close();\n    }\n  }\n"""
new = """  static Future<String?> _recognizePath(String path) async {\n    final source = File(path);\n    try {\n      if (!await source.exists() || await source.length() <= 0) return null;\n    } catch (_) {\n      return null;\n    }\n\n    // google_mlkit_text_recognition on iOS constructs MLKVisionImage from a\n    // UIImage. The plugin currently lets ML Kit raise an Objective-C exception\n    // when UIImage(contentsOfFile:) is nil, which aborts the entire process and\n    // cannot be caught by Dart. Preflight with the same UIKit decoder first.\n    if (Platform.isIOS) {\n      try {\n        final decodable = await _mediaChannel.invokeMethod<bool>(\n          'validateImageForOcr',\n          {'path': path},\n        );\n        if (decodable != true) return null;\n      } catch (_) {\n        return null;\n      }\n    }\n\n    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);\n    try {\n      final recognized = await recognizer.processImage(\n        InputImage.fromFilePath(path),\n      );\n      return extractFromRecognizedText(recognized.text);\n    } catch (_) {\n      return null;\n    } finally {\n      await recognizer.close();\n    }\n  }\n"""
s = replace_once(s, old, new, 'recognize path')
p.write_text(s)

# Native UIKit preflight on the same MethodChannel already used for media.
p = Path('ios/Runner/SceneDelegate.swift')
s = p.read_text()
needle = """      } else if call.method == \"extractVideoFrame\" {\n        guard\n          let args = call.arguments as? [String: Any],\n          let path = args[\"path\"] as? String,\n          !path.isEmpty\n"""
replacement = """      } else if call.method == \"validateImageForOcr\" {\n        guard\n          let args = call.arguments as? [String: Any],\n          let path = args[\"path\"] as? String,\n          !path.isEmpty\n        else {\n          result(false)\n          return\n        }\n        self.validateImageForOcr(path: path, result: result)\n      } else if call.method == \"extractVideoFrame\" {\n        guard\n          let args = call.arguments as? [String: Any],\n          let path = args[\"path\"] as? String,\n          !path.isEmpty\n"""
s = replace_once(s, needle, replacement, 'SceneDelegate method handler')
needle = """\n\n  private func pickOriginalPhoto(result: @escaping FlutterResult) {\n"""
replacement = """\n\n  private func validateImageForOcr(path: String, result: @escaping FlutterResult) {\n    DispatchQueue.global(qos: .userInitiated).async {\n      let fileExists = FileManager.default.fileExists(atPath: path)\n      let image = fileExists ? UIImage(contentsOfFile: path) : nil\n      DispatchQueue.main.async {\n        result(image != nil)\n      }\n    }\n  }\n\n  private func pickOriginalPhoto(result: @escaping FlutterResult) {\n"""
s = replace_once(s, needle, replacement, 'SceneDelegate validation method')
p.write_text(s)

# Share extension: do not persist an image-typed attachment unless UIKit can
# actually decode it. Invalid file representations fall back to loadItem,
# where UIImage/Data is validated before being stored.
p = Path('ios/SigillumShareExtension/ShareViewController.swift')
s = p.read_text()
needle = """  private func isFileBackedType(_ type: String) -> Bool {\n    return type == UTType.movie.identifier ||\n"""
replacement = """  private func isImageType(_ type: String) -> Bool {\n    return type == UTType.image.identifier ||\n      type == UTType.jpeg.identifier ||\n      type == UTType.png.identifier ||\n      type == kUTTypeImage as String\n  }\n\n  private func isFileBackedType(_ type: String) -> Bool {\n    return type == UTType.movie.identifier ||\n"""
s = replace_once(s, needle, replacement, 'share image type helper')
needle = """      if let url = item as? URL {\n        return try copyFileUrl(url, to: inbox, preferredType: preferredType)\n      }\n\n      if let image = item as? UIImage, let data = image.jpegData(compressionQuality: 0.95) {\n"""
replacement = """      if let url = item as? URL {\n        if isImageType(preferredType) && UIImage(contentsOfFile: url.path) == nil {\n          return nil\n        }\n        return try copyFileUrl(url, to: inbox, preferredType: preferredType)\n      }\n\n      if let image = item as? UIImage, let data = image.jpegData(compressionQuality: 0.95) {\n"""
s = replace_once(s, needle, replacement, 'share URL validation')
needle = """      if let data = item as? Data {\n        let destination = inbox.appendingPathComponent(fileName(ext: extensionForType(preferredType)))\n        try data.write(to: destination, options: .atomic)\n        return destination\n      }\n\n      if let data = item as? NSData {\n        let destination = inbox.appendingPathComponent(fileName(ext: extensionForType(preferredType)))\n        try data.write(to: destination, options: .atomic)\n        return destination\n      }\n"""
replacement = """      if let data = item as? Data {\n        if isImageType(preferredType) {\n          guard\n            let image = UIImage(data: data),\n            let normalized = image.jpegData(compressionQuality: 0.95)\n          else {\n            return nil\n          }\n          let destination = inbox.appendingPathComponent(fileName(ext: \"jpg\"))\n          try normalized.write(to: destination, options: .atomic)\n          return destination\n        }\n        let destination = inbox.appendingPathComponent(fileName(ext: extensionForType(preferredType)))\n        try data.write(to: destination, options: .atomic)\n        return destination\n      }\n\n      if let data = item as? NSData {\n        let swiftData = data as Data\n        if isImageType(preferredType) {\n          guard\n            let image = UIImage(data: swiftData),\n            let normalized = image.jpegData(compressionQuality: 0.95)\n          else {\n            return nil\n          }\n          let destination = inbox.appendingPathComponent(fileName(ext: \"jpg\"))\n          try normalized.write(to: destination, options: .atomic)\n          return destination\n        }\n        let destination = inbox.appendingPathComponent(fileName(ext: extensionForType(preferredType)))\n        try swiftData.write(to: destination, options: .atomic)\n        return destination\n      }\n"""
s = replace_once(s, needle, replacement, 'share Data validation')
needle = """      try FileManager.default.createDirectory(\n        at: inbox,\n        withIntermediateDirectories: true\n      )\n      return try copyFileUrl(url, to: inbox, preferredType: preferredType)\n"""
replacement = """      try FileManager.default.createDirectory(\n        at: inbox,\n        withIntermediateDirectories: true\n      )\n      if isImageType(preferredType) && UIImage(contentsOfFile: url.path) == nil {\n        return nil\n      }\n      return try copyFileUrl(url, to: inbox, preferredType: preferredType)\n"""
s = replace_once(s, needle, replacement, 'share file representation validation')
p.write_text(s)

# Regression contract tied directly to the TestFlight crash signature.
p = Path('test/messenger_mlkit_image_preflight_contract_test.dart')
p.write_text("""import 'dart:io';\n\nimport 'package:flutter_test/flutter_test.dart';\n\nvoid main() {\n  test('iOS OCR preflights UIKit decoding before invoking ML Kit', () {\n    final ocr = File('lib/hcv_media_id_ocr.dart').readAsStringSync();\n    final scene = File('ios/Runner/SceneDelegate.swift').readAsStringSync();\n\n    expect(ocr, contains("static const MethodChannel _mediaChannel = MethodChannel('hcv.media')"));\n    expect(ocr, contains("'validateImageForOcr'"));\n    expect(ocr, contains('if (decodable != true) return null;'));\n    expect(ocr, contains('InputImage.fromFilePath(path)'));\n    expect(\n      ocr.indexOf("'validateImageForOcr'"),\n      lessThan(ocr.indexOf('InputImage.fromFilePath(path)')),\n    );\n\n    expect(scene, contains('call.method == \"validateImageForOcr\"'));\n    expect(scene, contains('UIImage(contentsOfFile: path)'));\n    expect(scene, contains('result(image != nil)'));\n  });\n\n  test('share extension rejects undecodable image representations before handoff', () {\n    final share = File(\n      'ios/SigillumShareExtension/ShareViewController.swift',\n    ).readAsStringSync();\n\n    expect(share, contains('private func isImageType(_ type: String) -> Bool'));\n    expect(share, contains('UIImage(contentsOfFile: url.path) == nil'));\n    expect(share, contains('provider.loadItem(forTypeIdentifier: type, options: nil)'));\n    expect(share, contains('let image = UIImage(data: data)'));\n    expect(share, contains('let image = UIImage(data: swiftData)'));\n  });\n}\n""")

print('patched Messenger/MLKit crash guard')
