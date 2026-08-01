import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class HCVMLModelBundle {
  const HCVMLModelBundle({
    required this.modelFile,
    required this.labels,
    required this.source,
    this.manifest,
  });

  final File modelFile;
  final List<String> labels;
  final String source;
  final Map<String, dynamic>? manifest;
}

class HCVMLModelStore {
  HCVMLModelStore._();

  static final HCVMLModelStore instance = HCVMLModelStore._();

  static const assetModelPath = 'assets/ml/sigillum_screen_replay_v2.tflite';
  static const assetLabelsPath =
      'assets/ml/sigillum_screen_replay_v1_labels.json';

  Future<HCVMLModelBundle> loadCurrentBundle() async {
    final local = await _loadLocalBundle();
    if (local != null) return local;
    return _loadAssetBundle();
  }

  Future<HCVMLModelBundle> loadBundledBundle() async {
    return _loadAssetBundle();
  }

  Future<Map<String, dynamic>?> currentManifest() async {
    final dir = await _currentModelDirectory();
    final file = File(p.join(dir.path, 'manifest.json'));
    if (!await file.exists()) return null;

    try {
      final decoded = jsonDecode(await file.readAsString());
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  Future<String> installModelZip(String zipPath) async {
    final source = File(zipPath);
    if (!await source.exists()) {
      throw Exception('ZIP modello non trovato: $zipPath');
    }

    final archive = ZipDecoder().decodeBytes(await source.readAsBytes());
    final modelEntry = _firstFile(
      archive,
      (name) => name.endsWith('.tflite'),
    );
    final labelsEntry = _firstFile(
      archive,
      (name) => name.endsWith('labels.json') || name == 'labels.json',
    );

    if (modelEntry == null || labelsEntry == null) {
      throw Exception('ZIP modello incompleto: mancano .tflite o labels.json');
    }

    final staging = await _stagingModelDirectory();
    if (await staging.exists()) {
      await staging.delete(recursive: true);
    }
    await staging.create(recursive: true);

    final modelBytes = modelEntry.content as List<int>;
    final labelsBytes = labelsEntry.content as List<int>;
    final modelFile = File(p.join(staging.path, 'model.tflite'));
    final labelsFile = File(p.join(staging.path, 'labels.json'));
    await modelFile.writeAsBytes(modelBytes, flush: true);
    await labelsFile.writeAsBytes(labelsBytes, flush: true);

    final labels = _decodeLabels(utf8.decode(labelsBytes));
    if (labels.isEmpty) {
      throw Exception('labels.json non contiene classi valide');
    }

    final manifestEntry =
        _firstFile(archive, (name) => name == 'manifest.json');
    final manifest = <String, dynamic>{
      'type': 'SIGILLUM_LOCAL_MODEL_BUNDLE_V1',
      'installedAt': DateTime.now().toIso8601String(),
      'sourceZip': p.basename(zipPath),
      'modelFile': 'model.tflite',
      'labelsFile': 'labels.json',
      'modelSha256': sha256.convert(modelBytes).toString(),
      'labelsSha256': sha256.convert(labelsBytes).toString(),
      'classes': labels,
    };

    if (manifestEntry != null) {
      try {
        final decoded = jsonDecode(utf8.decode(manifestEntry.content));
        if (decoded is Map<String, dynamic>) {
          manifest['trainerManifest'] = decoded;
        }
      } catch (_) {}
    }

    await File(p.join(staging.path, 'manifest.json')).writeAsString(
      const JsonEncoder.withIndent('  ').convert(manifest),
      encoding: utf8,
      flush: true,
    );

    final current = await _currentModelDirectory();
    if (await current.exists()) {
      await current.delete(recursive: true);
    }
    await staging.rename(current.path);
    return current.path;
  }

  Future<void> clearLocalModel() async {
    final dir = await _currentModelDirectory();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  ArchiveFile? _firstFile(Archive archive, bool Function(String name) match) {
    for (final file in archive.files) {
      final name = file.name.replaceAll('\\', '/').split('/').last;
      if (file.isFile && match(name.toLowerCase())) return file;
    }
    return null;
  }

  Future<HCVMLModelBundle?> _loadLocalBundle() async {
    final dir = await _currentModelDirectory();
    final modelFile = File(p.join(dir.path, 'model.tflite'));
    final labelsFile = File(p.join(dir.path, 'labels.json'));
    if (!await modelFile.exists() || !await labelsFile.exists()) return null;

    final labels = _decodeLabels(await labelsFile.readAsString());
    if (labels.isEmpty) return null;

    return HCVMLModelBundle(
      modelFile: modelFile,
      labels: labels,
      source: 'LOCAL_UPDATED_MODEL',
      manifest: await currentManifest(),
    );
  }

  Future<HCVMLModelBundle> _loadAssetBundle() async {
    final tempDir = await getTemporaryDirectory();
    final modelFile = File(p.join(tempDir.path, p.basename(assetModelPath)));
    final asset = await rootBundle.load(assetModelPath);
    await modelFile.writeAsBytes(
      asset.buffer.asUint8List(asset.offsetInBytes, asset.lengthInBytes),
      flush: true,
    );

    final rawLabels = await rootBundle.loadString(assetLabelsPath);
    return HCVMLModelBundle(
      modelFile: modelFile,
      labels: _decodeLabels(rawLabels),
      source: 'BUNDLED_ASSET_MODEL',
    );
  }

  List<String> _decodeLabels(String rawLabels) {
    try {
      final decoded = jsonDecode(rawLabels);
      final classes = decoded is Map ? decoded['classes'] : null;
      if (classes is List) {
        return classes.map((value) => value.toString()).toList();
      }
    } catch (_) {}
    return const [];
  }

  Future<Directory> _currentModelDirectory() async {
    final root = await getApplicationDocumentsDirectory();
    return Directory(p.join(root.path, 'sigillum_ml_models', 'current'));
  }

  Future<Directory> _stagingModelDirectory() async {
    final root = await getApplicationDocumentsDirectory();
    return Directory(p.join(root.path, 'sigillum_ml_models', 'staging'));
  }
}
