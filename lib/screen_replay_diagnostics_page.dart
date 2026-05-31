import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'hcv_screen_replay_analyzer.dart';
import 'hcv_ml_screen_replay_classifier.dart';

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
      final isVideo = lower.endsWith('.mp4') || lower.endsWith('.mov');
      final staticData = isVideo
          ? await analyzer.analyzeVideo(path)
          : await analyzer.analyzeImage(path);
      final mlData = isVideo
          ? await HCVMLScreenReplayClassifier.instance.analyzeVideo(path)
          : await HCVMLScreenReplayClassifier.instance.analyzeImage(path);
      final data = _combine(staticData, mlData);

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

  String _nestedValue(String parent, String key) {
    final nested = analysis?[parent];
    if (nested is! Map) return '-';
    final value = nested[key];
    return value == null ? '-' : value.toString();
  }

  Map<String, dynamic> _combine(
    Map<String, dynamic> staticData,
    Map<String, dynamic> mlData,
  ) {
    final staticScore = (staticData['screenReplayRiskScore'] as num?)?.toInt();
    final mlScore = (mlData['screenReplayRiskScore'] as num?)?.toInt();
    final score = [
      if (staticScore != null) staticScore,
      if (mlScore != null) mlScore,
    ].fold<int?>(null, (best, value) {
      if (best == null || value > best) return value;
      return best;
    });

    return {
      'type': 'SIGILLUM_SCREEN_REPLAY_DIAGNOSTIC_WITH_ML_V1',
      'screenReplayRisk': score == null ? 'UNKNOWN' : _riskLabel(score),
      'screenReplayRiskScore': score,
      'staticScreenReplayAnalysis': staticData,
      'mlScreenReplayAnalysis': mlData,
    };
  }

  String _riskLabel(int riskScore) {
    return riskScore >= 60
        ? 'HIGH'
        : riskScore >= 35
            ? 'MEDIUM'
            : 'LOW';
  }

  String _reportText() {
    if (analysis == null) return '';

    const encoder = JsonEncoder.withIndent('  ');
    return [
      'SIGILLUM SCREEN DIAGNOSTIC',
      'file: ${selectedPath ?? '-'}',
      'risk: ${_value('screenReplayRisk')}',
      'score: ${_value('screenReplayRiskScore')}',
      'mlPredictedClass: ${_nestedValue('mlScreenReplayAnalysis', 'predictedClass')}',
      'mlScreenProbability: ${_nestedValue('mlScreenReplayAnalysis', 'screenProbability')}',
      'mlReason: ${_nestedValue('mlScreenReplayAnalysis', 'reason')}',
      'localTemporalFlickerScore: ${_nestedValue('staticScreenReplayAnalysis', 'localTemporalFlickerScore')}',
      'refreshBandScore: ${_nestedValue('staticScreenReplayAnalysis', 'refreshBandScore')}',
      'pixelGridUniformityScore: ${_nestedValue('staticScreenReplayAnalysis', 'pixelGridUniformityScore')}',
      'gridLikeScore: ${_nestedValue('staticScreenReplayAnalysis', 'gridLikeScore')}',
      'uniformityScore: ${_nestedValue('staticScreenReplayAnalysis', 'uniformityScore')}',
      'rectangleEdgeScore: ${_nestedValue('staticScreenReplayAnalysis', 'rectangleEdgeScore')}',
      'microVariationScore: ${_nestedValue('staticScreenReplayAnalysis', 'microVariationScore')}',
      'raw:',
      encoder.convert(analysis),
    ].join('\n');
  }

  Widget _nestedMetric(String label, String parent, String key) {
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
          Flexible(
            child: Text(
              _nestedValue(parent, key),
              textAlign: TextAlign.right,
            ),
          ),
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
              const SizedBox(height: 8),
              const Text(
                'Questa schermata analizza il file gia salvato. '
                'Il controllo live prima dello scatto si vede nel certificato.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.black54),
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
                const Text(
                  'ANALISI ML',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _nestedMetric(
                    'Classe', 'mlScreenReplayAnalysis', 'predictedClass'),
                _nestedMetric(
                    'Prob. schermo', 'mlScreenReplayAnalysis', 'screenProbability'),
                _nestedMetric('Score ML', 'mlScreenReplayAnalysis',
                    'screenReplayRiskScore'),
                _nestedMetric(
                    'Reason', 'mlScreenReplayAnalysis', 'reason'),
                _nestedMetric('Error', 'mlScreenReplayAnalysis', 'error'),
                const SizedBox(height: 20),
                const Text(
                  'ANALISI CLASSICA',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _nestedMetric('Local Flicker', 'staticScreenReplayAnalysis',
                    'localTemporalFlickerScore'),
                _nestedMetric('Refresh Band', 'staticScreenReplayAnalysis',
                    'refreshBandScore'),
                _nestedMetric('Pixel Grid', 'staticScreenReplayAnalysis',
                    'pixelGridUniformityScore'),
                _nestedMetric(
                    'Grid/Moire', 'staticScreenReplayAnalysis', 'gridLikeScore'),
                _nestedMetric(
                    'Uniformity', 'staticScreenReplayAnalysis', 'uniformityScore'),
                _nestedMetric('Rectangle Edge', 'staticScreenReplayAnalysis',
                    'rectangleEdgeScore'),
                _nestedMetric('Micro Variation', 'staticScreenReplayAnalysis',
                    'microVariationScore'),
                _nestedMetric(
                    'Frames', 'staticScreenReplayAnalysis', 'framesAnalyzed'),
                _nestedMetric(
                    'Segments', 'staticScreenReplayAnalysis', 'segmentsAnalyzed'),
                _nestedMetric('Worst Second', 'staticScreenReplayAnalysis',
                    'worstSegmentSecond'),
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
