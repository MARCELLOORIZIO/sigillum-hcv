import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:camera/camera.dart';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'hcv_ai_training_service.dart';
import 'hcv_live_screen_probe.dart';
import 'hcv_ml_model_store.dart';
import 'hcv_ml_screen_replay_classifier.dart';

class ScreenReplayCalibrationPage extends StatefulWidget {
  const ScreenReplayCalibrationPage({super.key});

  @override
  State<ScreenReplayCalibrationPage> createState() =>
      _ScreenReplayCalibrationPageState();
}

class _ScreenReplayCalibrationPageState
    extends State<ScreenReplayCalibrationPage> {
  CameraController? controller;
  List<CameraDescription> cameras = [];
  bool ready = false;
  bool running = false;
  bool autoRunning = false;
  String selectedLabel = 'SCREEN_MONITOR';
  int autoSampleCount = 5;
  String status = 'Scegli la classe ML e avvia il test.';
  String? aiTrainerEndpoint;
  String modelStatus = 'Modello locale: asset app';
  final samples = <Map<String, dynamic>>[];
  final labels = const [
    'SCREEN_MONITOR',
    'SCREEN_PHONE',
    'SCREEN_TABLET',
    'REALITY_PAPER',
    'REALITY_ROOM',
    'REALITY_OBJECT',
    'REALITY_OUTDOOR',
  ];

  @override
  void initState() {
    super.initState();
    loadTrainerSettings();
    initCamera();
  }

  Future<void> loadTrainerSettings() async {
    final endpoint = await HCVAiTrainingService.instance.endpoint();
    final manifest = await HCVMLModelStore.instance.currentManifest();
    if (!mounted) return;
    setState(() {
      aiTrainerEndpoint = endpoint;
      modelStatus = manifest == null
          ? 'Modello locale: asset app'
          : 'Modello locale: aggiornato ${manifest['installedAt'] ?? ''}';
    });
  }

  Future<void> initCamera() async {
    try {
      cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => status = 'Camera non disponibile.');
        return;
      }

      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final next = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.bgra8888,
      );

      await next.initialize();
      if (!mounted) {
        await next.dispose();
        return;
      }

      setState(() {
        controller = next;
        ready = true;
        status = 'Camera pronta.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => status = 'Errore camera: $e');
    }
  }

  Future<void> runCalibration() async {
    final current = controller;
    if (current == null || !current.value.isInitialized || running) return;

    setState(() {
      running = true;
      status = 'Raccolta campione ML: $selectedLabel';
    });

    try {
      final capturedImages = await _captureMlImages(current);
      final mlProposal = await _proposeLabelFromImages(capturedImages);
      if (!mounted) return;
      final confirmedLabel = await _confirmSampleLabel(mlProposal);
      if (confirmedLabel == null) {
        if (!mounted) return;
        setState(() {
          status = 'Campione scartato: nessuna label confermata.';
        });
        return;
      }

      final confirmedImages =
          await _moveImagesToLabel(capturedImages, confirmedLabel);
      if (!mounted) return;
      final analysis = await HCVLiveScreenProbe().analyzePreview(
        current,
        duration: const Duration(seconds: 10),
        maxFrames: 180,
        useOpticalProbeZoom: true,
      );

      final sample = {
        'sampleId': _newSampleId(),
        'label': confirmedLabel,
        'proposedLabel': mlProposal['label'],
        'proposalConfidence': mlProposal['confidence'],
        'proposalSource': mlProposal['source'],
        'aiTrainerReview': mlProposal['aiTrainerReview'],
        'labelConfirmedByUser': true,
        'createdAt': DateTime.now().toIso8601String(),
        'captureDevice': current.description.name,
        'imagePaths': confirmedImages,
        'mlImageAnalyses': mlProposal['analyses'],
        'analysis': analysis,
      };

      if (!mounted) return;
      setState(() {
        samples.add(sample);
        selectedLabel = confirmedLabel;
        status =
            'Campione ML salvato: $confirmedLabel / ${confirmedImages.length} immagini / ${analysis['screenReplayRisk']}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => status = 'Errore test: $e');
    } finally {
      if (mounted) {
        setState(() => running = false);
      }
    }
  }

  Future<void> runAutomaticCalibration() async {
    final current = controller;
    if (current == null || !current.value.isInitialized || running) return;

    setState(() {
      autoRunning = true;
      status = 'Raccolta automatica: 0/$autoSampleCount $selectedLabel';
    });

    try {
      for (var i = 0; i < autoSampleCount; i++) {
        if (!mounted) return;

        setState(() {
          status =
              'Raccolta automatica: ${i + 1}/$autoSampleCount $selectedLabel';
        });

        await runCalibration();

        if (i < autoSampleCount - 1) {
          await Future.delayed(const Duration(seconds: 2));
        }
      }

      if (!mounted) return;
      setState(() {
        status =
            'Raccolta automatica completata: $autoSampleCount campioni $selectedLabel';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => status = 'Errore raccolta automatica: $e');
    } finally {
      if (mounted) {
        setState(() => autoRunning = false);
      }
    }
  }

  Future<void> copyDataset() async {
    if (samples.isEmpty) return;

    const encoder = JsonEncoder.withIndent('  ');
    final text = encoder.convert(await _buildDatasetManifest());

    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Manifest copiato')),
    );
  }

  Future<void> shareDatasetByEmail() async {
    if (samples.isEmpty) return;

    final file = await _writeDatasetZip();
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/zip')],
      subject: 'SIGILLUM ML training dataset',
      text:
          'ZIP dataset SIGILLUM: contiene immagini reali e manifest JSON. Dopo unzip usa ml/prepare_dataset.py --source sigillum_ml_dataset.',
    );
  }

  Future<void> saveDatasetFile() async {
    if (samples.isEmpty) return;

    final file = await _writeDatasetZip();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('ZIP dataset salvato: ${file.path}')),
    );
  }

  Future<void> saveManifestFile() async {
    if (samples.isEmpty) return;

    final file = await _writeDatasetFile();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Manifest salvato: ${file.path}')),
    );
  }

  Future<void> configureAiTrainer() async {
    final controller = TextEditingController(text: aiTrainerEndpoint ?? '');
    final endpoint = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Server AI Trainer'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Endpoint',
              hintText: 'https://tuo-server.example',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, ''),
              child: const Text('DISATTIVA'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('SALVA'),
            ),
          ],
        );
      },
    );

    if (endpoint == null) return;
    await HCVAiTrainingService.instance.setEndpoint(endpoint);
    await loadTrainerSettings();
    if (!mounted) return;
    setState(() {
      status = endpoint.trim().isEmpty
          ? 'AI Trainer disattivato.'
          : 'AI Trainer configurato.';
    });
  }

  Future<void> importLocalModelZip() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
    );
    final path = result?.files.single.path;
    if (path == null) return;

    setState(() => status = 'Installazione modello locale...');
    try {
      final installedPath = await HCVMLModelStore.instance.installModelZip(path);
      HCVMLScreenReplayClassifier.instance.resetLoadedModel();
      await loadTrainerSettings();
      if (!mounted) return;
      setState(() => status = 'Modello locale aggiornato: $installedPath');
    } catch (e) {
      if (!mounted) return;
      setState(() => status = 'Errore modello locale: $e');
    }
  }

  Future<void> clearLocalModel() async {
    await HCVMLModelStore.instance.clearLocalModel();
    HCVMLScreenReplayClassifier.instance.resetLoadedModel();
    await loadTrainerSettings();
    if (!mounted) return;
    setState(() => status = 'Ripristinato modello incluso nell’app.');
  }

  Future<File> _writeDatasetFile() async {
    const encoder = JsonEncoder.withIndent('  ');
    final manifest = await _buildDatasetManifest();
    final exportManifest = Map<String, dynamic>.from(manifest);
    for (final sample in exportManifest['samples'] as List<dynamic>) {
      for (final imageItem in sample['images'] as List<dynamic>) {
        (imageItem as Map<String, dynamic>).remove('sourcePath');
      }
    }
    final text = encoder.convert(exportManifest);

    final dir = await _exportDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '')
        .replaceAll('.', '_');
    final file = File(p.join(dir.path, 'sigillum_ml_dataset_$stamp.json'));
    await file.writeAsString(text, encoding: utf8);
    return file;
  }

  Future<File> _writeDatasetZip() async {
    final manifest = await _buildDatasetManifest();
    final archive = Archive();
    final usedNames = <String>{};

    for (final sample in manifest['samples'] as List<dynamic>) {
      final images = sample['images'] as List<dynamic>;
      for (final imageItem in images) {
        final imageMap = imageItem as Map<String, dynamic>;
        final sourcePath = imageMap['sourcePath']?.toString();
        final zipPath = imageMap['path']?.toString();
        if (sourcePath == null || zipPath == null) continue;

        final file = File(sourcePath);
        if (!await file.exists()) continue;

        final bytes = await file.readAsBytes();
        var archivePath = zipPath.replaceAll('\\', '/');
        var suffix = 1;
        while (usedNames.contains(archivePath)) {
          final extension = p.extension(archivePath);
          final withoutExtension =
              archivePath.substring(0, archivePath.length - extension.length);
          archivePath = '${withoutExtension}_$suffix$extension';
          suffix++;
        }
        usedNames.add(archivePath);
        archive.addFile(ArchiveFile(archivePath, bytes.length, bytes));
      }
    }

    final exportManifest = Map<String, dynamic>.from(manifest);
    for (final sample in exportManifest['samples'] as List<dynamic>) {
      for (final imageItem in sample['images'] as List<dynamic>) {
        (imageItem as Map<String, dynamic>).remove('sourcePath');
      }
    }

    final manifestBytes = utf8.encode(
      const JsonEncoder.withIndent('  ').convert(exportManifest),
    );
    archive.addFile(
      ArchiveFile('manifest.json', manifestBytes.length, manifestBytes),
    );

    final readmeBytes = utf8.encode(
      'SIGILLUM ML dataset export\n\n'
      'Compatibile con:\n'
      'python ml/prepare_dataset.py --source sigillum_ml_dataset\n'
      'python ml/train_tflite.py --dataset ml_work/dataset\n',
    );
    archive.addFile(ArchiveFile('README.txt', readmeBytes.length, readmeBytes));

    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes == null) {
      throw Exception('Errore creazione ZIP dataset');
    }

    final dir = await _exportDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '')
        .replaceAll('.', '_');
    final file = File(p.join(dir.path, 'sigillum_ml_training_$stamp.zip'));
    await file.writeAsBytes(zipBytes, flush: true);
    return file;
  }

  Future<Map<String, dynamic>> _buildDatasetManifest() async {
    final manifestSamples = <Map<String, dynamic>>[];
    final counts = {for (final label in labels) label: 0};

    for (final sample in samples) {
      final label = sample['label']?.toString() ?? selectedLabel;
      final sampleId = sample['sampleId']?.toString() ?? _newSampleId();
      final imagePaths = (sample['imagePaths'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList();
      final imageItems = <Map<String, dynamic>>[];

      for (var i = 0; i < imagePaths.length; i++) {
        final sourcePath = imagePaths[i];
        final file = File(sourcePath);
        if (!await file.exists()) continue;

        final bytes = await file.readAsBytes();
        final extension = p.extension(sourcePath).toLowerCase();
        final safeExtension = extension == '.png' ? '.png' : '.jpg';
        final fileName = '${sampleId}_${(i + 1).toString().padLeft(2, '0')}'
            '$safeExtension';
        final relativePath = p
            .join('sigillum_ml_dataset', label, fileName)
            .replaceAll('\\', '/');

        imageItems.add({
          'path': relativePath,
          'sourcePath': sourcePath,
          'sha256': sha256.convert(bytes).toString(),
          'bytes': bytes.length,
        });
        counts[label] = (counts[label] ?? 0) + 1;
      }

      manifestSamples.add({
        'sampleId': sampleId,
        'label': label,
        'proposedLabel': sample['proposedLabel'],
        'proposalConfidence': sample['proposalConfidence'],
        'proposalSource': sample['proposalSource'],
        'aiTrainerReview': sample['aiTrainerReview'],
        'labelConfirmedByUser': sample['labelConfirmedByUser'] == true,
        'createdAt': sample['createdAt'],
        'captureDevice': sample['captureDevice'],
        'images': imageItems,
        'analysis': sample['analysis'],
        'mlImageAnalyses': sample['mlImageAnalyses'],
      });
    }

    return {
      'type': 'SIGILLUM_SCREEN_REPLAY_ASSISTED_TRAINING_EXPORT_V1',
      'compatibleWith': {
        'prepareDataset': 'ml/prepare_dataset.py',
        'trainTflite': 'ml/train_tflite.py',
        'sourceDirectoryInZip': 'sigillum_ml_dataset',
      },
      'classes': labels,
      'createdAt': DateTime.now().toIso8601String(),
      'imageRoot': 'sigillum_ml_dataset',
      'countsByClass': counts,
      'samples': manifestSamples,
    };
  }

  Future<Directory> _exportDirectory() async {
    if (Platform.isAndroid) {
      final dir = Directory('/storage/emulated/0/Download');
      if (await dir.exists()) return dir;
    }

    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null && userProfile.isNotEmpty) {
        return Directory(p.join(userProfile, 'Documents'));
      }
    }

    return getApplicationDocumentsDirectory();
  }

  Future<List<String>> _captureMlImages(CameraController current) async {
    final dir = await _datasetDirectory(selectedLabel);
    final paths = <String>[];

    for (var i = 0; i < 3; i++) {
      final photo = await current.takePicture();
      final target = File(
        p.join(
          dir.path,
          '${DateTime.now().millisecondsSinceEpoch}_${i + 1}.jpg',
        ),
      );
      await File(photo.path).copy(target.path);
      paths.add(target.path);
      await Future.delayed(const Duration(milliseconds: 350));
    }

    return paths;
  }

  Future<Map<String, dynamic>> _proposeLabelFromImages(
    List<String> imagePaths,
  ) async {
    final analyses = <Map<String, dynamic>>[];
    final scores = {for (final label in labels) label: 0.0};

    for (final imagePath in imagePaths) {
      try {
        final analysis =
            await HCVMLScreenReplayClassifier.instance.analyzeImage(imagePath);
        analyses.add(analysis);
        final probabilities = analysis['classProbabilities'];
        if (probabilities is Map) {
          for (final label in labels) {
            final value = probabilities[label];
            if (value is num) {
              scores[label] = (scores[label] ?? 0) + value.toDouble();
            }
          }
        } else {
          final predicted = analysis['predictedClass']?.toString();
          final confidence =
              (analysis['predictedClassConfidence'] as num?)?.toDouble() ?? 0;
          if (predicted != null && scores.containsKey(predicted)) {
            scores[predicted] = (scores[predicted] ?? 0) + confidence;
          }
        }
      } catch (e) {
        analyses.add({
          'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
          'screenReplayRisk': 'UNKNOWN',
          'reason': 'ASSISTED_LABEL_PROPOSAL_ERROR',
          'error': e.toString(),
        });
      }
    }

    var bestLabel = selectedLabel;
    var bestScore = -1.0;
    scores.forEach((label, score) {
      if (score > bestScore) {
        bestLabel = label;
        bestScore = score;
      }
    });

    final confidence =
        imagePaths.isEmpty ? 0.0 : (bestScore / imagePaths.length).clamp(0, 1);
    final localProposal = {
      'label': bestScore <= 0 ? selectedLabel : bestLabel,
      'confidence': double.parse(confidence.toStringAsFixed(4)),
      'source': bestScore <= 0
          ? 'USER_SELECTED_FALLBACK'
          : 'SIGILLUM_SCREEN_REPLAY_TFLITE',
      'scores': scores,
      'analyses': analyses,
    };

    try {
      final aiReview = await HCVAiTrainingService.instance.analyzeSample(
        imagePaths: imagePaths,
        userSelectedLabel: selectedLabel,
        classes: labels,
        localProposal: localProposal,
      );
      if (aiReview != null) {
        final aiLabel = aiReview['suggestedLabel']?.toString();
        final aiConfidence = (aiReview['confidence'] as num?)?.toDouble();
        if (aiLabel != null && labels.contains(aiLabel)) {
          return {
            ...localProposal,
            'label': aiLabel,
            'confidence': double.parse(
              (aiConfidence ?? confidence).clamp(0.0, 1.0).toStringAsFixed(4),
            ),
            'source': 'SIGILLUM_AI_TRAINER_CLOUD',
            'aiTrainerReview': aiReview,
          };
        }
      }
    } catch (e) {
      return {
        ...localProposal,
        'aiTrainerReview': {
          'error': e.toString(),
          'fallback': 'LOCAL_TFLITE_PROPOSAL',
        },
      };
    }

    return localProposal;
  }

  Future<String?> _confirmSampleLabel(Map<String, dynamic> proposal) async {
    var value = proposal['label']?.toString() ?? selectedLabel;
    if (!labels.contains(value)) value = selectedLabel;
    final confidence = ((proposal['confidence'] as num?)?.toDouble() ?? 0) * 100;
    final aiReview = proposal['aiTrainerReview'];
    final aiReason = aiReview is Map ? aiReview['reason']?.toString() : null;
    final aiQuality = aiReview is Map ? aiReview['quality']?.toString() : null;
    final nextInstruction =
        aiReview is Map ? aiReview['nextInstruction']?.toString() : null;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        var dialogValue = value;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Conferma label ML'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Proposta: $value (${confidence.toStringAsFixed(1)}%)\n'
                    'Fonte: ${proposal['source']}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (aiQuality != null || aiReason != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      [
                        if (aiQuality != null) 'Qualita: $aiQuality',
                        if (aiReason != null) aiReason,
                      ].join('\n'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                  if (nextInstruction != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      nextInstruction,
                      style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: dialogValue,
                    decoration: const InputDecoration(
                      labelText: 'Label corretta',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final label in labels)
                        DropdownMenuItem(value: label, child: Text(label)),
                    ],
                    onChanged: (next) {
                      if (next == null) return;
                      setDialogState(() => dialogValue = next);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('SCARTA'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, dialogValue),
                  child: const Text('CONFERMA'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<List<String>> _moveImagesToLabel(
    List<String> imagePaths,
    String label,
  ) async {
    final dir = await _datasetDirectory(label);
    final movedPaths = <String>[];

    for (final imagePath in imagePaths) {
      final file = File(imagePath);
      if (!await file.exists()) continue;

      final currentParent = p.dirname(file.path);
      if (p.equals(currentParent, dir.path)) {
        movedPaths.add(file.path);
        continue;
      }

      var targetPath = p.join(dir.path, p.basename(file.path));
      var suffix = 1;
      while (await File(targetPath).exists()) {
        targetPath = p.join(
          dir.path,
          '${p.basenameWithoutExtension(file.path)}_$suffix'
          '${p.extension(file.path)}',
        );
        suffix++;
      }
      final moved = await file.rename(targetPath);
      movedPaths.add(moved.path);
    }

    return movedPaths;
  }

  Future<Directory> _datasetDirectory(String label) async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(root.path, 'sigillum_ml_dataset', label));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String _newSampleId() {
    return 'sample_${DateTime.now().microsecondsSinceEpoch}';
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  Widget _choiceButton(String label) {
    final selected = selectedLabel == label;
    return OutlinedButton(
      onPressed: running || autoRunning
          ? null
          : () {
              setState(() => selectedLabel = label);
            },
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? Colors.black : null,
        foregroundColor: selected ? Colors.white : null,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = controller;
    final busy = running || autoRunning;

    return Scaffold(
      appBar: AppBar(title: const Text('Auto Training ML')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 3 / 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ready && current != null
                      ? CameraPreview(current)
                      : Container(
                          color: Colors.black12,
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Scegli la label iniziale del campione. Dopo la cattura '
                'SIGILLUM propone una label ML da confermare o correggere.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 10),
              Text(
                aiTrainerEndpoint == null
                    ? 'AI Trainer cloud: non configurato'
                    : 'AI Trainer cloud: attivo',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: aiTrainerEndpoint == null
                      ? Colors.orange.shade800
                      : Colors.green.shade700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                modelStatus,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : configureAiTrainer,
                      icon: const Icon(Icons.cloud_sync),
                      label: const Text('AI SERVER'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : importLocalModelZip,
                      icon: const Icon(Icons.system_update_alt),
                      label: const Text('MODELLO ZIP'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: busy ? null : clearLocalModel,
                icon: const Icon(Icons.restore),
                label: const Text("USA MODELLO INCLUSO NELL'APP"),
              ),
              const SizedBox(height: 10),
              const Text(
                'Label dataset',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (final label in labels) _choiceButton(label),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Campioni assistiti',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  DropdownButton<int>(
                    value: autoSampleCount,
                    onChanged: busy
                        ? null
                        : (value) {
                            if (value == null) return;
                            setState(() => autoSampleCount = value);
                          },
                    items: const [
                      DropdownMenuItem(value: 3, child: Text('3')),
                      DropdownMenuItem(value: 5, child: Text('5')),
                      DropdownMenuItem(value: 10, child: Text('10')),
                      DropdownMenuItem(value: 15, child: Text('15')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: ready && !busy ? runCalibration : null,
                icon: const Icon(Icons.model_training),
                label: Text(
                  running
                      ? 'RACCOLTA IN CORSO...'
                      : 'RACCOGLI E CONFERMA LABEL',
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: ready && !busy ? runAutomaticCalibration : null,
                icon: const Icon(Icons.playlist_add_check),
                label: Text(
                  autoRunning
                      ? 'RACCOLTA AUTOMATICA...'
                      : 'AVVIA AUTO $autoSampleCount CAMPIONI',
                ),
              ),
              const SizedBox(height: 16),
              Text(
                status,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              Text(
                'Campioni raccolti: ${samples.length}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: samples.isEmpty ? null : copyDataset,
                icon: const Icon(Icons.copy),
                label: const Text('COPIA MANIFEST'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: samples.isEmpty ? null : saveDatasetFile,
                      icon: const Icon(Icons.save_alt),
                      label: const Text('ZIP'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: samples.isEmpty ? null : shareDatasetByEmail,
                      icon: const Icon(Icons.mail_outline),
                      label: const Text('EMAIL'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: samples.isEmpty ? null : saveManifestFile,
                icon: const Icon(Icons.description),
                label: const Text('SALVA SOLO MANIFEST'),
              ),
              const SizedBox(height: 18),
              for (final sample in samples.reversed.take(8))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${sample['label']} - '
                    '${sample['analysis']['screenReplayRisk']} / '
                    '${sample['analysis']['screenReplayRiskScore']} - '
                    'local ${sample['analysis']['localTemporalFlickerScore']} - '
                    'band ${sample['analysis']['refreshBandScore']} - '
                    'stripe ${sample['analysis']['fineStripeScore']} - '
                    'grid ${sample['analysis']['fineGridScore']} - '
                    'dyn ${sample['analysis']['dynamicChallengeScore']} - '
                    'persist ${sample['analysis']['persistentPatternScore']}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
