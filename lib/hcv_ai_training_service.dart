import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

class HCVAiTrainingService {
  HCVAiTrainingService._();

  static final HCVAiTrainingService instance = HCVAiTrainingService._();

  static const _endpointKey = 'sigillum_ai_trainer_endpoint';

  Future<String?> endpoint() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_endpointKey)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  Future<void> setEndpoint(String value) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await prefs.remove(_endpointKey);
    } else {
      await prefs.setString(_endpointKey, trimmed);
    }
  }

  Future<Map<String, dynamic>?> analyzeSample({
    required List<String> imagePaths,
    required String userSelectedLabel,
    required List<String> classes,
    Map<String, dynamic>? localProposal,
  }) async {
    final baseEndpoint = await endpoint();
    if (baseEndpoint == null) return null;

    final uri = Uri.parse(baseEndpoint).resolve('/sigillum/ai-trainer/analyze');
    final images = <Map<String, dynamic>>[];
    for (final imagePath in imagePaths.take(5)) {
      final file = File(imagePath);
      if (!await file.exists()) continue;
      images.add({
        'fileName': p.basename(imagePath),
        'mimeType': _mimeType(imagePath),
        'base64': base64Encode(await file.readAsBytes()),
      });
    }

    if (images.isEmpty) return null;

    final payload = {
      'type': 'SIGILLUM_AI_TRAINER_SAMPLE_REQUEST_V1',
      'createdAt': DateTime.now().toIso8601String(),
      'userSelectedLabel': userSelectedLabel,
      'classes': classes,
      'localProposal': localProposal,
      'images': images,
      'expectedResponse': {
        'suggestedLabel': 'one of classes',
        'confidence': '0..1',
        'screenReplayRisk': 'LOW|MEDIUM|HIGH|UNKNOWN',
        'quality': 'GOOD_FOR_TRAINING|REVIEW|REJECT',
        'reason': 'short explanation',
        'nextInstruction': 'short instruction for next samples',
      },
    };

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 20);
    try {
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.write(jsonEncode(payload));

      final response = await request.close().timeout(
            const Duration(seconds: 45),
          );
      final text = await utf8.decodeStream(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('AI trainer HTTP ${response.statusCode}: $text');
      }

      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) return decoded;
      throw Exception('Risposta AI non valida');
    } finally {
      client.close(force: true);
    }
  }

  String _mimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    return 'image/jpeg';
  }
}
