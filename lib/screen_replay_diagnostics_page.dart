import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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
  final List<Map<String, dynamic>> batchResults = [];

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
        batchResults.add({
          'createdAt': DateTime.now().toIso8601String(),
          'file': path,
          'kind': isVideo ? 'video' : 'photo',
          'risk': data['screenReplayRisk'],
          'score': data['screenReplayRiskScore'],
          'mlClass': _mapValue(
            data,
            'mlScreenReplayAnalysis',
            'predictedClass',
          ),
          'mlScreenProbability': _mapValue(
            data,
            'mlScreenReplayAnalysis',
            'screenProbability',
          ),
          'mlScore': _mapValue(
            data,
            'mlScreenReplayAnalysis',
            'screenReplayRiskScore',
          ),
          'staticScore': _mapValue(
            data,
            'staticScreenReplayAnalysis',
            'screenReplayRiskScore',
          ),
          'localTemporalFlickerScore': _mapValue(
            data,
            'staticScreenReplayAnalysis',
            'localTemporalFlickerScore',
          ),
          'refreshBandScore': _mapValue(
            data,
            'staticScreenReplayAnalysis',
            'refreshBandScore',
          ),
        });
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

  Future<void> copyBatchReport() async {
    final text = _batchReportText();
    if (text.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report sessione copiato')),
    );
  }

  Future<void> saveBatchReport() async {
    final text = _batchReportText();
    if (text.isEmpty) return;

    final file = await _writeBatchReport(text);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sessione salvata: ${file.path}')),
    );
  }

  Future<void> shareBatchReport() async {
    final text = _batchReportText();
    if (text.isEmpty) return;

    final file = await _writeBatchReport(text);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/plain')],
      text: 'SIGILLUM screen diagnostic session',
    );
  }

  Future<File> _writeBatchReport(String text) async {
    final dir = await _outputDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '')
        .replaceAll('.', '_');
    final file = File('${dir.path}/sigillum_screen_session_$stamp.txt');
    await file.writeAsString(text, encoding: utf8);
    return file;
  }

  Future<Directory> _outputDirectory() async {
    if (Platform.isAndroid) {
      final dir = Directory('/storage/emulated/0/Download');
      if (await dir.exists()) return dir;
    }

    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null && userProfile.isNotEmpty) {
        return Directory('$userProfile\\Documents');
      }
    }

    return getApplicationDocumentsDirectory();
  }

  void clearBatch() {
    setState(() {
      batchResults.clear();
    });
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

  dynamic _mapValue(Map<String, dynamic> source, String parent, String key) {
    final nested = source[parent];
    if (nested is! Map) return null;
    return nested[key];
  }

  Map<String, dynamic> _combine(
    Map<String, dynamic> staticData,
    Map<String, dynamic> mlData,
  ) {
    final staticScore = (staticData['screenReplayRiskScore'] as num?)?.toInt();
    final mlScore = (mlData['screenReplayRiskScore'] as num?)?.toInt();
    final strongestScore = [
      if (staticScore != null) staticScore,
      if (mlScore != null) mlScore,
    ].fold<int?>(null, (best, value) {
      if (best == null || value > best) return value;
      return best;
    });
    final mlClass = mlData['predictedClass']?.toString();
    final mlSaysReality =
        mlClass != null && mlClass.startsWith('REALITY_') && mlScore != null;
    final score = mlSaysReality && mlScore <= 35 && strongestScore != null
        ? max(mlScore, min(strongestScore, 34))
        : strongestScore;

    return {
      'type': 'SIGILLUM_SCREEN_REPLAY_DIAGNOSTIC_WITH_ML_V1',
      'screenReplayRisk': score == null ? 'UNKNOWN' : _riskLabel(score),
      'screenReplayRiskScore': score,
      'staticScreenReplayAnalysis': staticData,
      'mlScreenReplayAnalysis': mlData,
    };
  }

  String _riskLabel(int riskScore) {
    return riskScore >= 80
        ? 'HIGH'
        : riskScore >= 55
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

  String _batchReportText() {
    if (batchResults.isEmpty) return '';

    const encoder = JsonEncoder.withIndent('  ');
    return [
      'SIGILLUM SCREEN DIAGNOSTIC SESSION',
      'createdAt: ${DateTime.now().toIso8601String()}',
      'samples: ${batchResults.length}',
      'summary: ${_batchSummaryText()}',
      'raw:',
      encoder.convert(batchResults),
    ].join('\n');
  }

  String _batchSummaryText() {
    if (batchResults.isEmpty) return '-';

    var low = 0;
    var medium = 0;
    var high = 0;
    var unknown = 0;
    for (final item in batchResults) {
      switch (item['risk']?.toString()) {
        case 'LOW':
          low++;
          break;
        case 'MEDIUM':
          medium++;
          break;
        case 'HIGH':
          high++;
          break;
        default:
          unknown++;
      }
    }
    return 'LOW $low - MEDIUM $medium - HIGH $high - UNKNOWN $unknown';
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
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: batchResults.isEmpty ? null : copyBatchReport,
                icon: const Icon(Icons.copy_all),
                label: Text('COPIA SESSIONE (${batchResults.length})'),
              ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          batchResults.isEmpty ? null : saveBatchReport,
                      icon: const Icon(Icons.save_alt),
                      label: const Text('SALVA'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          batchResults.isEmpty ? null : shareBatchReport,
                      icon: const Icon(Icons.ios_share),
                      label: const Text('CONDIVIDI'),
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: batchResults.isEmpty ? null : clearBatch,
                icon: const Icon(Icons.delete_outline),
                label: const Text('AZZERA SESSIONE'),
              ),
              const SizedBox(height: 16),
              if (batchResults.isNotEmpty) ...[
                Text(
                  _batchSummaryText(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                _batchList(),
                const SizedBox(height: 12),
              ],
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

  Widget _batchList() {
    final visible = batchResults.reversed.take(8).toList();
    return Column(
      children: [
        for (final item in visible)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 76,
                  child: Text(
                    '${item['risk'] ?? '-'} / ${item['score'] ?? '-'}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: item['risk'] == 'LOW'
                          ? Colors.green
                          : Colors.orange,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    '${item['mlClass'] ?? '-'}  p:${item['mlScreenProbability'] ?? '-'}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
