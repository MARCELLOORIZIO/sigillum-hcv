import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'hcv_screen_replay_analyzer.dart';

class ScreenReplayDiagnosticsPage extends StatefulWidget {
  const ScreenReplayDiagnosticsPage({super.key});

  @override
  State<ScreenReplayDiagnosticsPage> createState() =>
      _ScreenReplayDiagnosticsPageState();
}

class _ScreenReplayDiagnosticsPageState
    extends State<ScreenReplayDiagnosticsPage> {
  bool loading = false;
  String status = 'Seleziona una foto o un video di test.';
  String? selectedPath;
  Map<String, dynamic>? analysis;

  Future<void> pickAndAnalyze() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'mp4', 'mov'],
    );

    final path = result?.files.single.path;
    if (path == null || path.isEmpty) return;

    final lower = path.toLowerCase();

    setState(() {
      loading = true;
      selectedPath = path;
      analysis = null;
      status = 'Analisi in corso...';
    });

    try {
      final analyzer = HCVScreenReplayAnalyzer();
      final data = lower.endsWith('.mp4') || lower.endsWith('.mov')
          ? await analyzer.analyzeVideo(path)
          : await analyzer.analyzeImage(path);

      if (!mounted) return;
      setState(() {
        analysis = data;
        status = 'Analisi completata.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        status = 'Errore analisi: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> copyReport() async {
    final text = _reportText();
    if (text.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report copiato')),
    );
  }

  String _value(String key) {
    final value = analysis?[key];
    return value == null ? '-' : value.toString();
  }

  String _reportText() {
    if (analysis == null) return '';

    const encoder = JsonEncoder.withIndent('  ');
    return [
      'SIGILLUM SCREEN DIAGNOSTIC',
      'file: ${selectedPath ?? '-'}',
      'risk: ${_value('screenReplayRisk')}',
      'score: ${_value('screenReplayRiskScore')}',
      'localTemporalFlickerScore: ${_value('localTemporalFlickerScore')}',
      'refreshBandScore: ${_value('refreshBandScore')}',
      'pixelGridUniformityScore: ${_value('pixelGridUniformityScore')}',
      'gridLikeScore: ${_value('gridLikeScore')}',
      'uniformityScore: ${_value('uniformityScore')}',
      'rectangleEdgeScore: ${_value('rectangleEdgeScore')}',
      'microVariationScore: ${_value('microVariationScore')}',
      'raw:',
      encoder.convert(analysis),
    ].join('\n');
  }

  Widget _metric(String label, String key) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text(_value(key)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final risk = _value('screenReplayRisk');
    final score = _value('screenReplayRiskScore');

    return Scaffold(
      appBar: AppBar(title: const Text('Diagnostica schermo')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                onPressed: loading ? null : pickAndAnalyze,
                icon: const Icon(Icons.folder_open),
                label: const Text('SELEZIONA FOTO O VIDEO'),
              ),
              const SizedBox(height: 16),
              Text(
                status,
                textAlign: TextAlign.center,
              ),
              if (selectedPath != null) ...[
                const SizedBox(height: 12),
                Text(
                  selectedPath!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
              if (loading) ...[
                const SizedBox(height: 24),
                const Center(child: CircularProgressIndicator()),
              ],
              if (analysis != null) ...[
                const SizedBox(height: 24),
                Text(
                  '$risk / $score',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: risk == 'HIGH' || risk == 'MEDIUM'
                        ? Colors.orange
                        : Colors.green,
                  ),
                ),
                const SizedBox(height: 24),
                _metric('Local Flicker', 'localTemporalFlickerScore'),
                _metric('Refresh Band', 'refreshBandScore'),
                _metric('Pixel Grid', 'pixelGridUniformityScore'),
                _metric('Grid/Moire', 'gridLikeScore'),
                _metric('Uniformity', 'uniformityScore'),
                _metric('Rectangle Edge', 'rectangleEdgeScore'),
                _metric('Micro Variation', 'microVariationScore'),
                _metric('Frames', 'framesAnalyzed'),
                _metric('Segments', 'segmentsAnalyzed'),
                _metric('Worst Second', 'worstSegmentSecond'),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: copyReport,
                  icon: const Icon(Icons.copy),
                  label: const Text('COPIA REPORT'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
