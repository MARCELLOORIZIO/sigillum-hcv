import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'hcv_live_screen_probe.dart';

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
  String selectedLabel = 'SCREEN_MONITOR';
  String status = 'Scegli la classe ML e avvia il test.';
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
    initCamera();
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
      final analysis = await HCVLiveScreenProbe().analyzePreview(
        current,
        duration: const Duration(seconds: 10),
        maxFrames: 180,
        useOpticalProbeZoom: true,
      );

      final sample = {
        'label': selectedLabel,
        'createdAt': DateTime.now().toIso8601String(),
        'captureDevice': current.description.name,
        'imagePaths': capturedImages,
        'analysis': analysis,
      };

      if (!mounted) return;
      setState(() {
        samples.add(sample);
        status =
            'Campione ML salvato: $selectedLabel / ${capturedImages.length} immagini / ${analysis['screenReplayRisk']}';
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

  Future<void> copyDataset() async {
    if (samples.isEmpty) return;

    const encoder = JsonEncoder.withIndent('  ');
    final text = encoder.convert({
      'type': 'SIGILLUM_SCREEN_REPLAY_ML_DATASET_V1',
      'classes': labels,
      'samples': samples,
    });

    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dataset copiato')),
    );
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

  Future<Directory> _datasetDirectory(String label) async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(root.path, 'sigillum_ml_dataset', label));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  Widget _choiceButton(String label) {
    final selected = selectedLabel == label;
    return OutlinedButton(
      onPressed: running
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

    return Scaffold(
      appBar: AppBar(title: const Text('Calibrazione schermo')),
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
                'Raccoglie immagini etichettate per il modello ML SIGILLUM '
                'e misura anche il live probe fisico.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.black54),
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
              ElevatedButton.icon(
                onPressed: ready && !running ? runCalibration : null,
                icon: const Icon(Icons.sensors),
                label: Text(running ? 'TEST IN CORSO...' : 'AVVIA TEST 10 SEC'),
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
                label: const Text('COPIA DATASET'),
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
