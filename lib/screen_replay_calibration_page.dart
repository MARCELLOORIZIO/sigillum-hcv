import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  String selectedLabel = 'SCREEN';
  String status = 'Scegli il tipo di scena e avvia il test.';
  final samples = <Map<String, dynamic>>[];

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
      status = selectedLabel == 'SCREEN'
          ? 'Test SCHERMO in corso: muovi leggermente iPhone.'
          : 'Test REALTA in corso: muovi leggermente iPhone.';
    });

    try {
      final analysis = await HCVLiveScreenProbe().analyzePreview(
        current,
        duration: const Duration(seconds: 10),
        maxFrames: 180,
      );

      final sample = {
        'label': selectedLabel,
        'createdAt': DateTime.now().toIso8601String(),
        'analysis': analysis,
      };

      if (!mounted) return;
      setState(() {
        samples.add(sample);
        status =
            'Campione salvato: $selectedLabel / ${analysis['screenReplayRisk']} / ${analysis['screenReplayRiskScore']}';
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
      'type': 'SIGILLUM_SCREEN_REPLAY_CALIBRATION_DATASET_V1',
      'samples': samples,
    });

    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dataset copiato')),
    );
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  Widget _choiceButton(String label, String text) {
    final selected = selectedLabel == label;
    return Expanded(
      child: OutlinedButton(
        onPressed: running
            ? null
            : () {
                setState(() => selectedLabel = label);
              },
        style: OutlinedButton.styleFrom(
          backgroundColor: selected ? Colors.black : null,
          foregroundColor: selected ? Colors.white : null,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: Text(text),
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
              Row(
                children: [
                  _choiceButton('SCREEN', 'SCHERMO'),
                  const SizedBox(width: 12),
                  _choiceButton('REALITY', 'REALTA'),
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
                    'band ${sample['analysis']['refreshBandScore']}',
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
