import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'hcv_registry_service.dart';
import 'hcv_verifier.dart';

import 'package:path/path.dart' as p;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

import 'hcv_social_fingerprint.dart';
import 'hcv_media_id_ocr.dart';
import 'sigillum_localization.dart';
import 'sigillum_theme.dart';
import 'verification_ui_copy.dart';

class HCVDisplayRiskClaimValues {
  const HCVDisplayRiskClaimValues({
    required this.risk,
    required this.score,
    required this.decision,
    required this.requiresLegacyNormalization,
  });

  final String? risk;
  final String? score;
  final String? decision;
  final bool requiresLegacyNormalization;
}

HCVDisplayRiskClaimValues resolveHCVDisplayRiskClaimValues(
  Map<dynamic, dynamic> claims,
) {
  final evidence = claims['displayRiskEvidence'];
  final signedRisk = evidence is Map ? evidence['risk']?.toString() : null;
  final signedScore = evidence is Map ? evidence['score']?.toString() : null;
  final signedDecision = evidence is Map
      ? evidence['decision']?.toString()
      : null;
  final hasCompleteSignedEvidence =
      signedRisk != null && signedScore != null && signedDecision != null;

  if (hasCompleteSignedEvidence) {
    return HCVDisplayRiskClaimValues(
      risk: signedRisk,
      score: signedScore,
      decision: signedDecision,
      requiresLegacyNormalization: false,
    );
  }

  return HCVDisplayRiskClaimValues(
    risk: claims['screenReplayRisk']?.toString(),
    score: claims['screenReplayRiskScore']?.toString(),
    decision: claims['displayRiskDecision']?.toString(),
    requiresLegacyNormalization: true,
  );
}

class RegistryVerifyPage extends StatefulWidget {
  final String? initialMediaPath;
  final String? initialHcvId;
  final String languageCode;

  const RegistryVerifyPage({
    super.key,
    this.initialMediaPath,
    this.initialHcvId,
    this.languageCode = 'it',
  });

  @override
  State<RegistryVerifyPage> createState() => _RegistryVerifyPageState();
}

class _RegistryVerifyPageState extends State<RegistryVerifyPage> {
  static const MethodChannel _mediaChannel = MethodChannel('hcv.media');

  String _t(String key) => SigillumCopy.t(widget.languageCode, key);
  String _v(String key) => VerificationUiCopy.t(widget.languageCode, key);

  String? extractHcvIdFromName(String fileName) {
    final patterns = [
      RegExp(r'hcv_video_(HCV-[A-F0-9]{16})(?![A-F0-9])', caseSensitive: false),
      RegExp(r'(HCV-[A-F0-9]{16})(?![A-F0-9])', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(fileName);

      if (match != null) {
        return match.group(1)!.toUpperCase();
      }
    }

    return null;
  }

  String? extractHcvIdFromText(String value) {
    final normalized = value
        .toUpperCase()
        .replaceAll('HCV-ID:', 'HCV-')
        .replaceAll('HCV ID:', 'HCV-')
        .replaceAll('HCVID:', 'HCV-')
        .replaceAll('ID:', '')
        .replaceAll('HCV_ID', 'HCV-')
        .replaceAll('HCV_', 'HCV-');

    final match = RegExp(r'HCV-[A-F0-9]{16}(?![A-F0-9])')
        .firstMatch(normalized);
    return match?.group(0);
  }

  String normalizeSocialText(String value) {
    final footer = RegExp(
      r'\s+HCV VERIFIED\s*[^\r\n]*\s+ID:\s*HCV-(?:[A-F0-9]{16}|[A-F0-9]{8})\s+VERIFY WITH SIGILLUM\s*$',
      caseSensitive: false,
      multiLine: true,
    );

    return value.replaceFirst(footer, '').trim();
  }

  Future<String?> extractHcvIdFromTextFile(String path) async {
    try {
      final text = await File(path).readAsString();
      return extractHcvIdFromText(text);
    } catch (_) {
      return null;
    }
  }

  Future<String?> detectHcvIdFromMediaPath(String path) async {
    final fileName = p.basename(path);
    final fromName = extractHcvIdFromName(fileName);

    if (fromName != null) {
      return fromName;
    }

    final lowerPath = path.toLowerCase();

    if (lowerPath.endsWith('.jpg') ||
        lowerPath.endsWith('.jpeg') ||
        lowerPath.endsWith('.png')) {
      return extractHcvIdFromImage(path);
    }

    if (lowerPath.endsWith('.mp4') ||
        lowerPath.endsWith('.mov') ||
        lowerPath.endsWith('.m4v')) {
      return extractHcvIdFromVideoFrame(path);
    }

    if (lowerPath.endsWith('.txt')) {
      return extractHcvIdFromTextFile(path);
    }

    return null;
  }

  Future<String?> extractHcvIdFromImage(String path) async {
    return HCVMediaIdOcr.extractFromImage(path);
  }

  Future<String?> extractHcvIdFromVideoFrame(String videoPath) async {
    // Fast pre-check only: SIGILLUM watermark/HCV-ID should be visible
    // immediately. Do not scan the whole video when the ID is absent.
    final times = ['00:00:00.2', '00:00:00.8'];

    for (final time in times) {
      if (!mounted) return null;
      try {
        final framePath = Platform.isIOS
            ? await _extractNativeVideoFrame(
                videoPath,
                double.parse(time.substring(6)),
              )
            : await _extractFfmpegVideoFrame(videoPath, time);

        if (framePath != null) {
          final id = await extractHcvIdFromImage(framePath);

          try {
            final frameFile = File(framePath);
            if (await frameFile.exists()) {
              await frameFile.delete();
            }
          } catch (_) {}

          if (id != null && id.isNotEmpty) {
            return id;
          }
        }
      } catch (_) {}
    }

    return null;
  }

  Future<String?> _extractNativeVideoFrame(
    String videoPath,
    double seconds,
  ) async {
    try {
      return await _mediaChannel.invokeMethod<String>('extractVideoFrame', {
        'path': videoPath,
        'seconds': seconds,
      });
    } catch (_) {
      return null;
    }
  }

  Future<String?> _extractFfmpegVideoFrame(
    String videoPath,
    String time,
  ) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final framePath =
          '${tempDir.path}/hcv_ocr_frame_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final command =
          "-y -ss $time -i '$videoPath' "
          "-vf \"crop=iw:ih*0.40:0:0,scale=iw*2:ih*2,eq=contrast=1.6:brightness=0.05:saturation=1.2\" "
          "-frames:v 1 '$framePath'";

      final session = await FFmpegKit.execute(command);
      final code = await session.getReturnCode();

      if (code != null && ReturnCode.isSuccess(code)) {
        return framePath;
      }
    } catch (_) {}

    return null;
  }

  List<String> _b8Variants(String hcvId) {
    final match = RegExp(r'^HCV-([A-F0-9]{16})$').firstMatch(hcvId);

    if (match == null) {
      return const [];
    }

    final chars = match.group(1)!.split('');
    final positions = <int>[];

    for (var i = 0; i < chars.length; i++) {
      if (chars[i] == '8' || chars[i] == 'B') {
        positions.add(i);
      }
    }

    if (positions.isEmpty) {
      return const [];
    }

    final variants = <String>{};

    void walk(int positionIndex, List<String> current) {
      if (variants.length >= 64) {
        return;
      }

      if (positionIndex == positions.length) {
        variants.add('HCV-${current.join()}');
        return;
      }

      final index = positions[positionIndex];
      final original = current[index];
      final alternate = original == '8' ? 'B' : '8';

      walk(positionIndex + 1, current);

      current[index] = alternate;
      walk(positionIndex + 1, current);
      current[index] = original;
    }

    walk(0, List<String>.from(chars));
    variants.remove(hcvId);

    return variants.toList();
  }

  Future<MapEntry<String, Map<String, dynamic>>> _fetchCertificate(
    String hcvId,
  ) async {
    try {
      return MapEntry(hcvId, await registry.fetchCertificate(hcvId));
    } catch (originalError) {
      for (final candidate in _b8Variants(hcvId)) {
        try {
          return MapEntry(
            candidate,
            await registry.fetchCertificate(candidate),
          );
        } catch (_) {}
      }

      throw originalError;
    }
  }

  Future<File?> _findLocalCertificate(String hcvId) async {
    final root = await getApplicationDocumentsDirectory();
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final lower = entity.path.toLowerCase();
      if (!lower.endsWith('.hcv') ||
          !p.basename(entity.path).toUpperCase().contains(hcvId)) {
        continue;
      }
      try {
        final decoded = jsonDecode(await entity.readAsString());
        final meta = decoded is Map ? decoded['meta'] : null;
        if (meta is Map && meta['hcvId']?.toString().toUpperCase() == hcvId) {
          return entity;
        }
      } catch (_) {}
    }
    return null;
  }

  Future<MapEntry<String, Map<String, dynamic>>>
  _fetchCertificateWithLocalRecovery(String hcvId) async {
    try {
      return await _fetchCertificate(hcvId);
    } on HCVRegistryException catch (error) {
      if (error.kind != HCVRegistryFailureKind.notFound) rethrow;

      try {
        await registry.retryPendingUploads();
        return await _fetchCertificate(hcvId);
      } catch (_) {}

      final localCertificate = await _findLocalCertificate(hcvId);
      if (localCertificate == null) throw error;
      try {
        await registry.uploadCertificateFile(localCertificate.path);
        return await _fetchCertificate(hcvId);
      } catch (_) {
        throw error;
      }
    }
  }

  Future<MapEntry<String, Map<String, dynamic>>>
  _fetchCertificateWithPhotoOcrRecovery(String hcvId) async {
    try {
      return await _fetchCertificateWithLocalRecovery(hcvId);
    } on HCVRegistryException catch (originalError) {
      final path = mediaPath;
      if (originalError.kind != HCVRegistryFailureKind.notFound ||
          path == null) {
        rethrow;
      }

      final lower = path.toLowerCase();
      final isPhoto =
          lower.endsWith('.jpg') ||
          lower.endsWith('.jpeg') ||
          lower.endsWith('.png');
      if (!isPhoto) rethrow;

      final candidates = await HCVMediaIdOcr.extractCandidatesFromImage(path);
      for (final candidate in candidates) {
        if (candidate == hcvId) continue;
        try {
          return await _fetchCertificate(candidate);
        } on HCVRegistryException catch (candidateError) {
          if (candidateError.kind == HCVRegistryFailureKind.notFound) {
            continue;
          }
          rethrow;
        }
      }

      throw originalError;
    }
  }

  int _hexDistance(String left, String right) {
    final maxLength = left.length < right.length ? left.length : right.length;
    var distance = (left.length - right.length).abs() * 4;

    for (var i = 0; i < maxLength; i++) {
      final a = int.tryParse(left[i], radix: 16);
      final b = int.tryParse(right[i], radix: 16);

      if (a == null || b == null) {
        distance += 4;
      } else {
        var diff = a ^ b;
        while (diff > 0) {
          distance += diff & 1;
          diff >>= 1;
        }
      }
    }

    return distance;
  }

  Future<bool?> _matchesCertifiedVideoFingerprint(
    Map<String, dynamic> cert,
  ) async {
    if (mediaPath == null) {
      return null;
    }

    final lowerPath = mediaPath!.toLowerCase();
    if (!lowerPath.endsWith('.mp4') &&
        !lowerPath.endsWith('.mov') &&
        !lowerPath.endsWith('.m4v')) {
      return null;
    }

    final claims = cert['claims'];
    if (claims is! Map) {
      return null;
    }

    final stored = claims['socialFingerprint'];
    if (stored is! Map) {
      return null;
    }

    final storedHashes = stored['frameHashes'];
    if (storedHashes is! List || storedHashes.isEmpty) {
      return null;
    }

    try {
      final current = await HCVSocialFingerprint().buildFromVideo(mediaPath!);
      final currentHashes = current['frameHashes'];

      if (currentHashes is! List || currentHashes.isEmpty) {
        return false;
      }

      return _videoFrameHashesMatch(storedHashes, currentHashes);
    } catch (_) {
      return false;
    }
  }

  bool _videoFrameHashesMatch(List storedHashes, List currentHashes) {
    final expected = storedHashes.map((value) => value.toString()).toList();
    final current = currentHashes.map((value) => value.toString()).toList();

    if (expected.isEmpty || current.isEmpty) {
      return false;
    }

    final usedCurrentIndexes = <int>{};
    var matched = 0;

    for (final expectedHash in expected) {
      var bestIndex = -1;
      var bestDistance = 9999;

      for (var i = 0; i < current.length; i++) {
        if (usedCurrentIndexes.contains(i)) continue;

        final distance = _hexDistance(expectedHash, current[i]);
        if (distance < bestDistance) {
          bestDistance = distance;
          bestIndex = i;
        }
      }

      if (bestIndex >= 0 && bestDistance <= 96) {
        usedCurrentIndexes.add(bestIndex);
        matched++;
      }
    }

    final comparableCount = expected.length < current.length
        ? expected.length
        : current.length;
    final requiredMatches = max(2, (comparableCount * 0.35).ceil());

    return matched >= requiredMatches;
  }

  Future<bool?> _matchesCertifiedImageFingerprint(
    Map<String, dynamic> cert,
  ) async {
    if (mediaPath == null) {
      return null;
    }

    final lowerPath = mediaPath!.toLowerCase();
    if (!lowerPath.endsWith('.jpg') &&
        !lowerPath.endsWith('.jpeg') &&
        !lowerPath.endsWith('.png')) {
      return null;
    }

    final claims = cert['claims'];
    if (claims is! Map) {
      return null;
    }

    final stored = claims['socialFingerprint'];
    if (stored is! Map) {
      return null;
    }

    final expected = stored['imageHash']?.toString();
    if (expected == null || expected.isEmpty) {
      return null;
    }

    try {
      final current = await HCVSocialFingerprint().buildFromImage(mediaPath!);
      final actual = current['imageHash']?.toString();

      if (actual == null || actual.isEmpty) {
        return false;
      }

      return _hexDistance(expected, actual) <= 72;
    } catch (_) {
      return false;
    }
  }

  final idController = TextEditingController();

  final registry = const HCVRegistryService();
  final verifier = HCVVerifier();

  String status =
      'Inserisci HCV-ID e seleziona il file originale da verificare';

  String? result;
  String? mediaPath;

  Map<String, dynamic>? certificate;

  String? creatorName;
  String? trustLevel;
  String? identityAssuranceLevel;
  String? legalIdentityStatus;
  String? identityFingerprint;
  String? creatorKeyFingerprint;
  String? contentType;
  String? hcvTrustLevel;
  String? liveCaptureTrust;
  String? screenReplayRisk;
  String? screenReplayRiskScore;
  String? displayRiskDecision;
  String? screenReplaySegmentsAnalyzed;
  String? screenReplayWorstSecond;
  String? liveProbeFrames;
  String? liveProbeRisk;
  String? liveProbeAnalysisStatus;
  String? liveProbeReason;
  String? liveProbeError;
  String? localTemporalFlickerScore;
  String? refreshBandScore;
  String? pixelGridUniformityScore;
  String? liveProbeLocalFlickerScore;
  String? liveProbeRefreshBandScore;
  String? liveProbeFineStripeScore;
  String? liveProbeFineGridScore;
  String? liveProbeMoireFrequencyScore;
  String? liveProbeDynamicChallengeScore;
  String? liveProbePersistentPatternScore;
  String? liveProbeOpticalCorroboratedTrace;
  String? liveProbeMoireFrequencyTrace;
  String? liveProbeDynamicScreenChallengeTrace;
  String? liveProbeUncorroboratedDisplayPattern;
  String? syntheticRisk;
  String? sceneAuthenticity;
  String? aiProofLevel;
  String? provenanceState;
  String? provenanceDetail;
  String? integrityState;
  String? integrityDetail;
  String? sceneState;
  String? sceneDetail;
  String? derivationState;
  String? derivationDetail;

  bool loading = false;
  bool hcvIdDetectedByOcr = false;

  @override
  void initState() {
    super.initState();

    status = _v('verificationIncomplete');
    final path = widget.initialMediaPath;

    if (path != null && path.isNotEmpty) {
      Future.microtask(() => _autoVerifySharedPath(path));
    }
  }

  Future<void> _autoVerifySharedPath(String path) async {
    if (!mounted) return;

    try {
      setState(() {
        mediaPath = path;
        result = null;
        status = 'Controllo rapido SIGILLUM in corso...';
        hcvIdDetectedByOcr = false;
      });

      final file = File(path);
      if (!await file.exists()) {
        if (!mounted) return;
        setState(() {
          result = 'NOT ANALYZED';
          status = 'File ricevuto ma non accessibile. Riprova da Verifica contenuto.';
        });
        return;
      }

      final suppliedId = widget.initialHcvId?.trim().toUpperCase();
      final detectedId =
          suppliedId != null &&
              RegExp(r'^HCV-[A-F0-9]{16}$').hasMatch(suppliedId)
          ? suppliedId
          : await detectHcvIdFromMediaPath(path);

      if (!mounted) return;

      if (detectedId == null || detectedId.isEmpty) {
        setState(() {
          result = null;
          status = 'Contenuto non certificato SIGILLUM.';
        });
        return;
      }

      setState(() {
        hcvIdDetectedByOcr = true;
        idController.text = detectedId;
        status = 'HCV-ID rilevato. Verifica Registry automatica...';
      });

      await verifyFromRegistry();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        result = 'NOT ANALYZED';
        status = 'Verifica automatica non completata. Il file e arrivato con un formato non leggibile automaticamente: inserisci HCV-ID e premi VERIFICA DA REGISTRY.';
      });
    }
  }

  @override
  void dispose() {
    idController.dispose();
    super.dispose();
  }

  Future<void> pickMedia() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      withData: false,
      allowedExtensions: [
        'mp4',
        'mov',
        'jpg',
        'jpeg',
        'png',
        'txt',
        'pdf',
        'mp3',
        'wav',
      ],
    );

    if (picked == null) return;

    hcvIdDetectedByOcr = false;

    final pickedFile = picked.files.single;
    String? path = pickedFile.path;

    if (path == null && pickedFile.bytes != null) {
      final dir = await getApplicationDocumentsDirectory();
      final localFile = File('${dir.path}/${pickedFile.name}');
      await localFile.writeAsBytes(pickedFile.bytes!);
      path = localFile.path;
    }

    if (path == null) {
      setState(() {
        status = 'File selezionato ma non importabile su iOS';
      });
      return;
    }

    final lowerPath = path.toLowerCase();

    if (lowerPath.endsWith('.hcv') || lowerPath.endsWith('.hcvpack')) {
      setState(() {
        mediaPath = null;
        result = 'INVALID';
        status = 'Qui devi selezionare il file ORIGINALE (mp4, jpg, pdf, txt, audio), NON .hcv o .hcvpack';
      });

      return;
    }

    final fileName = picked.files.single.name;

    final detectedId = extractHcvIdFromName(fileName);

    if (detectedId != null) {
      idController.text = detectedId;
    } else {
      String? ocrId;

      final lowerPath = path.toLowerCase();

      if (lowerPath.endsWith('.jpg') ||
          lowerPath.endsWith('.jpeg') ||
          lowerPath.endsWith('.png')) {
        ocrId = await extractHcvIdFromImage(path);
      } else if (lowerPath.endsWith('.mp4') ||
          lowerPath.endsWith('.mov') ||
          lowerPath.endsWith('.m4v')) {
        ocrId = await extractHcvIdFromVideoFrame(path);
      } else if (lowerPath.endsWith('.txt')) {
        ocrId = await extractHcvIdFromTextFile(path);
      }

      if (ocrId != null) {
        hcvIdDetectedByOcr = true;

        idController.text = ocrId;

        setState(() {
          status = 'HCV-ID rilevato via OCR nel media';
        });
      }

      if (ocrId != null) {
        idController.text = ocrId;

        setState(() {
          status = 'HCV-ID rilevato via OCR';
        });
      }
    }

    setState(() {
      mediaPath = path;
      result = null;

      status = idController.text.trim().isNotEmpty
          ? 'HCV-ID rilevato. Ora premi VERIFICA DA REGISTRY'
          : 'File selezionato. Se disponibile, inserisci o rileva HCV-ID e premi VERIFICA DA REGISTRY.';
    });
  }

  Future<void> verifyFromRegistry() async {
    var hcvId = idController.text.trim();

    if (hcvId.startsWith('hcv://verify/')) {
      hcvId = hcvId.replaceFirst('hcv://verify/', '');
    }

    hcvId = hcvId.toUpperCase();

    if (hcvId.isEmpty) {
      setState(() {
        status = 'Inserisci HCV-ID';
      });

      return;
    }

    if (mediaPath == null) {
      setState(() {
        status = 'Seleziona il file originale da verificare';
      });

      return;
    }

    setState(() {
      loading = true;

      result = null;

      status = 'Scaricamento certificato dal Registry HCV...';
      _clearVerificationAxes();

      certificate = null;

      creatorName = null;
      trustLevel = null;
      identityAssuranceLevel = null;
      legalIdentityStatus = null;
      identityFingerprint = null;
      creatorKeyFingerprint = null;
      contentType = null;
      hcvTrustLevel = null;
      liveCaptureTrust = null;
      screenReplayRisk = null;
      screenReplayRiskScore = null;
      displayRiskDecision = null;
      screenReplaySegmentsAnalyzed = null;
      screenReplayWorstSecond = null;
      liveProbeFrames = null;
      liveProbeRisk = null;
      liveProbeAnalysisStatus = null;
      liveProbeReason = null;
      liveProbeError = null;
      localTemporalFlickerScore = null;
      refreshBandScore = null;
      pixelGridUniformityScore = null;
      liveProbeLocalFlickerScore = null;
      liveProbeRefreshBandScore = null;
      liveProbeFineStripeScore = null;
      liveProbeFineGridScore = null;
      liveProbeMoireFrequencyScore = null;
      liveProbeDynamicChallengeScore = null;
      liveProbePersistentPatternScore = null;
      liveProbeOpticalCorroboratedTrace = null;
      liveProbeMoireFrequencyTrace = null;
      liveProbeDynamicScreenChallengeTrace = null;
      liveProbeUncorroboratedDisplayPattern = null;
      syntheticRisk = null;
      sceneAuthenticity = null;
      aiProofLevel = null;
    });

    try {
      final resolved = await _fetchCertificateWithPhotoOcrRecovery(hcvId);
      hcvId = resolved.key;
      final cert = resolved.value;
      idController.text = hcvId;

      final claims = cert['claims'];

      if (claims is Map) {
        hcvTrustLevel = claims['trustLevel']?.toString();
        liveCaptureTrust = claims['liveCaptureTrust']?.toString();
        final displayRiskClaims = resolveHCVDisplayRiskClaimValues(claims);
        screenReplayRisk = displayRiskClaims.risk;
        screenReplayRiskScore = displayRiskClaims.score;
        displayRiskDecision = displayRiskClaims.decision;
        final screenReplayAnalysis = claims['screenReplayAnalysis'];
        if (screenReplayAnalysis is Map) {
          screenReplaySegmentsAnalyzed =
              screenReplayAnalysis['segmentsAnalyzed']?.toString();
          screenReplayWorstSecond = screenReplayAnalysis['worstSegmentSecond']
              ?.toString();
          localTemporalFlickerScore =
              screenReplayAnalysis['localTemporalFlickerScore']?.toString();
          refreshBandScore = screenReplayAnalysis['refreshBandScore']
              ?.toString();
          pixelGridUniformityScore =
              screenReplayAnalysis['pixelGridUniformityScore']?.toString();
        }
        final liveScreenProbe = claims['liveScreenProbe'];
        if (liveScreenProbe is Map) {
          liveProbeFrames = liveScreenProbe['framesAnalyzed']?.toString();
          liveProbeRisk = liveScreenProbe['screenReplayRisk']?.toString();
          liveProbeAnalysisStatus = liveScreenProbe['analysisStatus']
              ?.toString();
          liveProbeReason = liveScreenProbe['reason']?.toString();
          liveProbeError = liveScreenProbe['error']?.toString();
          liveProbeLocalFlickerScore =
              liveScreenProbe['localTemporalFlickerScore']?.toString();
          liveProbeRefreshBandScore = liveScreenProbe['refreshBandScore']
              ?.toString();
          liveProbeFineStripeScore = liveScreenProbe['fineStripeScore']
              ?.toString();
          liveProbeFineGridScore = liveScreenProbe['fineGridScore']?.toString();
          liveProbeMoireFrequencyScore = liveScreenProbe['moireFrequencyScore']
              ?.toString();
          liveProbeDynamicChallengeScore =
              liveScreenProbe['dynamicChallengeScore']?.toString();
          liveProbePersistentPatternScore =
              liveScreenProbe['persistentPatternScore']?.toString();
          final liveProbeSignals = liveScreenProbe['signals'];
          if (liveProbeSignals is Map) {
            liveProbeOpticalCorroboratedTrace =
                liveProbeSignals['opticalCorroboratedTrace']?.toString();
            liveProbeMoireFrequencyTrace =
                liveProbeSignals['moireFrequencyTrace']?.toString();
            liveProbeDynamicScreenChallengeTrace =
                liveProbeSignals['dynamicScreenChallengeTrace']?.toString();
            liveProbeUncorroboratedDisplayPattern =
                liveProbeSignals['uncorroboratedDisplayPattern']?.toString();
          }
        }
        syntheticRisk = claims['syntheticRisk']?.toString();
        sceneAuthenticity = claims['sceneAuthenticity']?.toString();
        aiProofLevel = claims['aiProofLevel']?.toString();
        if (displayRiskClaims.requiresLegacyNormalization) {
          _normalizeScreenReplayRiskFromClaims(claims);
        }
      }

      final tempDir = await getTemporaryDirectory();

      final tempHcv = File('${tempDir.path}/$hcvId.hcv');

      await tempHcv.writeAsString(
        const JsonEncoder.withIndent('  ').convert(cert),
      );

      final certOk = await verifier.verifyFile(tempHcv.path);

      if (!certOk) {
        setState(() {
          loading = false;

          status = 'Certificato scaricato ma firma crittografica NON valida';

          result = 'INVALID';

          certificate = cert;
        });

        return;
      }

      final content = cert['content'];

      if (content is! Map<String, dynamic>) {
        setState(() {
          loading = false;

          status = 'Certificato senza content binding';

          result = 'INVALID';

          certificate = cert;
        });

        return;
      }

      final mediaFile = File(mediaPath!);

      if (!await mediaFile.exists()) {
        setState(() {
          loading = false;

          status = 'File media non trovato';

          result = 'INVALID';
        });

        return;
      }

      final mediaBytes = await mediaFile.readAsBytes();

      final actualHash = sha256.convert(mediaBytes).toString();

      final expectedHash = content['hash']?.toString();
      final contentTypeForVerification = content['type']?.toString();

      var socialTextVerified = false;

      if (contentTypeForVerification == 'text' &&
          mediaPath!.toLowerCase().endsWith('.txt')) {
        try {
          final text = await mediaFile.readAsString();
          final originalText = normalizeSocialText(text);
          final originalBytes = utf8.encode(originalText);
          final originalHash = sha256.convert(originalBytes).toString();
          socialTextVerified = originalHash == expectedHash;
        } catch (_) {
          socialTextVerified = false;
        }
      }

      final meta = cert['meta'];

      final identity = meta is Map ? meta['identity'] : null;

      if (identity is Map) {
        creatorName = identity['creatorName']?.toString();

        trustLevel = identity['trustLevel']?.toString();
        identityAssuranceLevel = identity['identityAssuranceLevel']?.toString();
        legalIdentityStatus = identity['legalIdentityStatus']?.toString();
        identityFingerprint = identity['identityFingerprint']?.toString();
        creatorKeyFingerprint = identity['devicePublicKeyFingerprint']
            ?.toString();
      }

      contentType = contentTypeForVerification;

      final forensicVerified = actualHash == expectedHash;
      final videoFingerprintMatches = await _matchesCertifiedVideoFingerprint(
        cert,
      );
      final imageFingerprintMatches = await _matchesCertifiedImageFingerprint(
        cert,
      );

      setState(() {
        loading = false;

        certificate = cert;

        void markVerified(String cleanStatus, String cleanResult) {
          final exactOriginal = cleanResult.startsWith('FORENSIC');
          final sceneWarning = _isStrongDisplayRisk;
          final sceneUncertain = _isDisplayNonConclusive;
          _setVerificationAxes(
            provenance: 'Verificata',
            provenanceDetail: 'Certificato Registry valido, identita tecnica e contenuto collegati.',
            integrity: exactOriginal
                ? 'Originale integro'
                : 'Derivato compatibile',
            integrityDetail: exactOriginal
                ? 'Hash SHA-256 identico all originale certificato.'
                : 'Hash diverso, ma evidenze compatibili con il certificato.',
            scene: sceneWarning
                ? 'Forte rischio display'
                : sceneUncertain
                ? 'Non conclusiva'
                : 'Nessun indizio display',
            sceneDetail: sceneWarning
                ? 'Piu segnali coerenti indicano una possibile ripresa da schermo.'
                : sceneUncertain
                ? 'Sono presenti anomalie ambigue, ma non prove sufficienti di ripresa da schermo.'
                : 'Nessun indizio tecnico sufficiente di ripresa da schermo.',
            derivation: exactOriginal ? 'Non necessaria' : 'Compatibile',
            derivationDetail: exactOriginal
                ? 'Il file corrisponde esattamente all originale.'
                : 'Il file sembra un derivato o una versione ricompressa.',
          );
          if (sceneWarning) {
            status =
                '$cleanStatus\n\n'
                'ATTENZIONE: possibile ripresa di uno schermo rilevata '
                '($screenReplayRisk). Il media è collegato al certificato, '
                'ma la scena non va trattata come ripresa diretta della realtà.';

            result = cleanResult;
          } else {
            status = cleanStatus;
            result = cleanResult;
          }
        }

        if (forensicVerified) {
          markVerified(
            'FORENSIC VERIFIED OK\nFile identico all originale certificato. Hash SHA-256 corrispondente.',
            'FORENSIC VERIFIED OK',
          );
        } else if (socialTextVerified) {
          markVerified(
            'SOCIAL VERIFIED OK\nTesto originale verificato. Il post contiene footer SIGILLUM/HCV-ID, quindi il file non e identico byte-per-byte ma il contenuto certificato corrisponde.',
            'SOCIAL VERIFIED OK',
          );
        } else {
          status = 'SOCIAL VERIFIED OK\nHash non identico al file certificato. HCV-ID e certificato Registry sono validi; la causa della differenza non e determinabile automaticamente.';

          final hcvIdWasDetectedInMedia = hcvIdDetectedByOcr;
          final hcvIdProvided = idController.text.trim().isNotEmpty;

          if (contentType == 'video' && videoFingerprintMatches == true) {
            markVerified(
              hcvIdWasDetectedInMedia
                  ? 'SOCIAL VERIFIED OK\nHCV-ID rilevato nel video, certificato Registry valido e fingerprint video compatibile. Hash diverso; HCV-ID e fingerprint restano compatibili. La causa della differenza non e determinabile automaticamente.'
                  : 'SOCIAL VERIFIED OK\nHCV-ID inserito, certificato Registry valido e fingerprint video compatibile. Hash diverso; HCV-ID e fingerprint restano compatibili. La causa della differenza non e determinabile automaticamente.',
              'SOCIAL VERIFIED OK',
            );
          } else if ((hcvIdWasDetectedInMedia || hcvIdProvided) &&
              contentType == 'video' &&
              videoFingerprintMatches == null) {
            markVerified(
              hcvIdWasDetectedInMedia
                  ? 'SOCIAL VERIFIED OK\nHCV-ID rilevato nel media e certificato Registry valido. Hash diverso; HCV-ID e fingerprint restano compatibili. La causa della differenza non e determinabile automaticamente.'
                  : 'SOCIAL VERIFIED OK\nHCV-ID inserito e certificato Registry valido. Hash diverso; HCV-ID e fingerprint restano compatibili. La causa della differenza non e determinabile automaticamente.',
              'SOCIAL VERIFIED OK',
            );
          } else if ((hcvIdWasDetectedInMedia || hcvIdProvided) &&
              contentType == 'video' &&
              videoFingerprintMatches == false) {
            status = hcvIdWasDetectedInMedia
                ? 'HCV-ID rilevato nel video, ma il fingerprint social non corrisponde al contenuto certificato. Possibile ID sovrapposto a un video diverso.'
                : 'HCV-ID inserito, ma il fingerprint social non corrisponde al contenuto certificato. Il video selezionato non risulta compatibile con quel certificato.';

            result = 'ID VALID / MEDIA NOT VERIFIED';
          } else if (contentType == 'photo' &&
              imageFingerprintMatches == true) {
            markVerified(
              hcvIdWasDetectedInMedia
                  ? 'SOCIAL VERIFIED OK\nHCV-ID rilevato nella foto, certificato Registry valido e fingerprint immagine compatibile. Hash diverso; HCV-ID e fingerprint restano compatibili. La causa della differenza non e determinabile automaticamente.'
                  : 'SOCIAL VERIFIED OK\nHCV-ID inserito, certificato Registry valido e fingerprint immagine compatibile. Hash diverso; HCV-ID e fingerprint restano compatibili. La causa della differenza non e determinabile automaticamente.',
              'SOCIAL VERIFIED OK',
            );
          } else if ((hcvIdWasDetectedInMedia || hcvIdProvided) &&
              contentType == 'photo' &&
              imageFingerprintMatches == null) {
            markVerified(
              hcvIdWasDetectedInMedia
                  ? 'SOCIAL VERIFIED OK\nHCV-ID rilevato nella foto e certificato Registry valido. Foto legacy senza fingerprint immagine: verifica social meno forte.'
                  : 'SOCIAL VERIFIED OK\nHCV-ID inserito e certificato Registry valido. Foto legacy senza fingerprint immagine: verifica social meno forte.',
              'SOCIAL VERIFIED OK',
            );
          } else if ((hcvIdWasDetectedInMedia || hcvIdProvided) &&
              contentType == 'photo' &&
              imageFingerprintMatches == false) {
            status = hcvIdWasDetectedInMedia
                ? 'HCV-ID rilevato nella foto, ma il fingerprint immagine non corrisponde al contenuto certificato. Possibile ID sovrapposto a una foto diversa.'
                : 'HCV-ID inserito, ma il fingerprint immagine non corrisponde al contenuto certificato. La foto selezionata non risulta compatibile con quel certificato.';

            result = 'ID VALID / MEDIA NOT VERIFIED';
          } else if (hcvIdWasDetectedInMedia && contentType != 'text') {
            markVerified(
              'SOCIAL VERIFIED OK\nHCV-ID rilevato nel media e certificato Registry valido. Hash diverso; HCV-ID e fingerprint restano compatibili. La causa della differenza non e determinabile automaticamente.',
              'SOCIAL VERIFIED OK',
            );
          } else {
            status = 'HCV-ID valido nel Registry, ma non rilevato automaticamente nel file selezionato. Verifica social non conclusiva.';

            result = 'ID VALID / MEDIA NOT VERIFIED';
          }
        }
      });
    } on HCVRegistryException catch (e) {
      setState(() {
        loading = false;
        certificate = null;

        switch (e.kind) {
          case HCVRegistryFailureKind.notFound:
            status = 'Certificato non presente nel Registry. Questo non dimostra che il file sia stato modificato: la pubblicazione online potrebbe essere ancora in attesa.';
            result = 'REGISTRY NOT FOUND';
            _setVerificationAxes(
              provenance: 'Non presente online',
              provenanceDetail: 'Il Registry non contiene ancora questo HCV-ID. Il file non viene dichiarato alterato.',
              integrity: 'Non determinata',
              integrityDetail: 'Senza il certificato online non e possibile confrontare firma e contenuto.',
              scene: 'Non analizzata',
              sceneDetail: 'Il controllo della scena non viene eseguito senza certificato.',
              derivation: null,
              derivationDetail: null,
            );
            break;
          case HCVRegistryFailureKind.unavailable:
          case HCVRegistryFailureKind.server:
            status = 'Registry temporaneamente non raggiungibile. Il file locale non viene considerato invalido; riprova quando la connessione e disponibile.';
            result = 'REGISTRY UNAVAILABLE';
            _setVerificationAxes(
              provenance: 'Registry non raggiungibile',
              provenanceDetail: 'La verifica online non e stata completata per un problema di rete o del server.',
              integrity: 'Non determinata',
              integrityDetail: 'Nessun verdetto di modifica e stato emesso.',
              scene: 'Non analizzata',
              sceneDetail: 'Il controllo della scena non viene eseguito senza certificato.',
              derivation: null,
              derivationDetail: null,
            );
            break;
          case HCVRegistryFailureKind.invalidResponse:
            status = 'Risposta Registry non utilizzabile: ${e.message}';
            result = 'REGISTRY ERROR';
            _setVerificationAxes(
              provenance: 'Verifica online incompleta',
              provenanceDetail: 'Il Registry ha risposto, ma la risposta non consente una verifica affidabile.',
              integrity: 'Non determinata',
              integrityDetail: 'Nessun verdetto di modifica e stato emesso.',
              scene: 'Non analizzata',
              sceneDetail: 'Il controllo della scena non viene eseguito senza certificato valido.',
              derivation: null,
              derivationDetail: null,
            );
            break;
          case HCVRegistryFailureKind.invalidCertificate:
            status = 'Certificato locale non valido: ${e.message}';
            result = 'INVALID';
            _setVerificationAxes(
              provenance: 'Non verificata',
              provenanceDetail:
                  'Il certificato locale non supera i controlli strutturali.',
              integrity: 'Non verificata',
              integrityDetail: 'Integrita non dimostrata.',
              scene: 'Non analizzata',
              sceneDetail: 'Il controllo della scena non viene usato per questo verdetto.',
              derivation: null,
              derivationDetail: null,
            );
            break;
        }
      });
    } catch (e) {
      setState(() {
        loading = false;
        certificate = null;
        status = 'Errore imprevisto durante la verifica Registry: $e';
        result = 'REGISTRY ERROR';
        _setVerificationAxes(
          provenance: 'Verifica online incompleta',
          provenanceDetail:
              'Non e stato possibile completare la verifica online.',
          integrity: 'Non determinata',
          integrityDetail: 'Nessun verdetto di modifica e stato emesso.',
          scene: 'Non analizzata',
          sceneDetail:
              'Il controllo della scena non viene eseguito senza certificato.',
          derivation: null,
          derivationDetail: null,
        );
      });
    }
  }

  bool get isVerified {
    final value = result ?? '';
    return value.startsWith('HUMAN VERIFIED') ||
        value.startsWith('FORENSIC VERIFIED') ||
        value.startsWith('SOCIAL VERIFIED');
  }

  bool get isScreenReplayWarning => (result ?? '').contains('SCREEN RISK');

  bool _isScreenReplayRisk(String? risk) {
    final value = risk?.toUpperCase();
    return value == 'MEDIUM' || value == 'HIGH';
  }

  int get _screenReplayScoreValue =>
      int.tryParse(screenReplayRiskScore ?? '') ?? 0;

  bool get _isStrongDisplayRisk =>
      (displayRiskDecision == 'STRONG_DISPLAY_RISK' &&
          _screenReplayScoreValue >= 70) ||
      (displayRiskDecision == null && screenReplayRisk == 'HIGH');

  bool get _isDisplayNonConclusive =>
      (displayRiskDecision == 'NON_CONCLUSIVE' &&
          _screenReplayScoreValue >= 45) ||
      (displayRiskDecision == null && screenReplayRisk == 'MEDIUM');

  String _screenReplayRiskLabel(int score) {
    return score >= 70
        ? 'HIGH'
        : score >= 45
        ? 'MEDIUM'
        : 'LOW';
  }

  void _normalizeScreenReplayRiskFromClaims(Map<dynamic, dynamic> claims) {
    final liveProbe = claims['liveScreenProbe'];
    if (liveProbe is! Map) return;

    final currentReplayScore = int.tryParse(screenReplayRiskScore ?? '');
    if (currentReplayScore == null) return;

    final ml = claims['mlScreenReplayAnalysis'];
    final passive = claims['screenReplayAnalysis'];
    final mlClass = ml is Map ? ml['predictedClass']?.toString() : null;
    final mlConfidence = ml is Map
        ? _asDouble(ml['predictedClassConfidence'])
        : 0.0;
    final mlScreenProbability = ml is Map
        ? _asDouble(ml['screenProbability'])
        : 1.0;
    final passiveScore = passive is Map
        ? (passive['screenReplayRiskScore'] as num?)?.toInt()
        : null;
    final liveSignals = liveProbe['signals'];
    final liveFineGrid = _asDouble(liveProbe['fineGridScore']);
    final liveFineStripe = _asDouble(liveProbe['fineStripeScore']);
    final livePersistent = _asDouble(liveProbe['persistentPatternScore']);
    final liveDynamic = _asDouble(liveProbe['dynamicChallengeScore']);
    final closeDisplaySpatialTrace =
        (liveSignals is Map &&
            liveSignals['closeDisplaySpatialTrace'] == true) ||
        (liveSignals is Map &&
            liveSignals['dynamicScreenChallengeTrace'] == true &&
            liveFineGrid > 0.85 &&
            liveFineStripe < 0.42 &&
            livePersistent > 0.85 &&
            liveDynamic < 0.18);
    final confirmedTemporalTrace =
        liveSignals is Map && liveSignals['confirmedDisplayTrace'] == true;
    final mlSaysReality =
        mlClass != null &&
        (mlClass.startsWith('REALITY_') || mlClass == 'REAL_SCENE') &&
        mlConfidence >= 0.60 &&
        mlScreenProbability < 0.35;
    final currentIsWarning = currentReplayScore >= 70;

    if (closeDisplaySpatialTrace &&
        confirmedTemporalTrace &&
        (passiveScore ?? 0) >= 45 &&
        currentReplayScore < 70) {
      screenReplayRiskScore = '70';
      screenReplayRisk = _screenReplayRiskLabel(70);
      displayRiskDecision = 'STRONG_DISPLAY_RISK';
      return;
    }

    if (currentIsWarning &&
        closeDisplaySpatialTrace &&
        !confirmedTemporalTrace &&
        (passiveScore == null || passiveScore < 45)) {
      final downgradedScore = passiveScore ?? 34;
      screenReplayRiskScore = downgradedScore.toString();
      screenReplayRisk = _screenReplayRiskLabel(downgradedScore);
      displayRiskDecision = downgradedScore >= 45
          ? 'NON_CONCLUSIVE'
          : 'NO_DISPLAY_EVIDENCE';
      return;
    }

    if (currentIsWarning &&
        mlSaysReality &&
        (passiveScore == null || passiveScore < 35)) {
      final downgradedScore = passiveScore ?? 20;
      screenReplayRiskScore = downgradedScore.toString();
      screenReplayRisk = _screenReplayRiskLabel(downgradedScore);
    }
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  void _clearVerificationAxes() {
    provenanceState = null;
    provenanceDetail = null;
    integrityState = null;
    integrityDetail = null;
    sceneState = null;
    sceneDetail = null;
    derivationState = null;
    derivationDetail = null;
  }

  void _setVerificationAxes({
    required String provenance,
    required String provenanceDetail,
    required String integrity,
    required String integrityDetail,
    required String scene,
    required String sceneDetail,
    String? derivation,
    String? derivationDetail,
  }) {
    provenanceState = provenance;
    this.provenanceDetail = provenanceDetail;
    integrityState = integrity;
    this.integrityDetail = integrityDetail;
    sceneState = scene;
    this.sceneDetail = sceneDetail;
    derivationState = derivation;
    this.derivationDetail = derivationDetail;
  }

  bool get _hasVerificationAxes =>
      provenanceState != null ||
      integrityState != null ||
      sceneState != null ||
      derivationState != null ||
      result != null;

  bool get _isMediaNotVerified => (result ?? '').contains('MEDIA NOT VERIFIED');

  bool get _isInvalidResult => (result ?? '').startsWith('INVALID');

  bool get _isRegistryWarningResult => (result ?? '').startsWith('REGISTRY ');

  bool get _isForensicResult => (result ?? '').startsWith('FORENSIC VERIFIED');

  bool get _isSocialResult => (result ?? '').startsWith('SOCIAL VERIFIED');

  String get _effectiveProvenanceState {
    if (provenanceState != null) return provenanceState!;
    if (_isMediaNotVerified) return 'HCV-ID valido';
    if (_isInvalidResult) return 'Non verificata';
    return '-';
  }

  String get _effectiveProvenanceDetail {
    if (provenanceDetail != null) return provenanceDetail!;
    if (_isMediaNotVerified) {
      return 'Il certificato esiste nel Registry, ma il file selezionato non corrisponde al contenuto certificato.';
    }
    if (_isInvalidResult) {
      return 'Non e stato possibile confermare certificato, firma o collegamento tecnico.';
    }
    return '-';
  }

  String get _effectiveIntegrityState {
    if (integrityState != null) return integrityState!;
    if (_isForensicResult) return 'Originale integro';
    if (_isSocialResult) return 'Derivato compatibile';
    if (_isMediaNotVerified) return 'Non originale';
    if (_isInvalidResult) return 'Non verificata';
    return '-';
  }

  String get _effectiveIntegrityDetail {
    if (integrityDetail != null) return integrityDetail!;
    if (_isForensicResult) {
      return 'Hash SHA-256 identico all originale certificato.';
    }
    if (_isSocialResult) {
      return 'Hash diverso, ma HCV-ID e fingerprint sono compatibili con il certificato.';
    }
    if (_isMediaNotVerified) {
      return 'Il media selezionato non supera il controllo di corrispondenza con il contenuto certificato.';
    }
    if (_isInvalidResult) {
      return 'Integrita non dimostrata.';
    }
    return '-';
  }

  String get _effectiveSceneState {
    if (sceneState != null) return sceneState!;
    if (_isStrongDisplayRisk) return 'Forte rischio display';
    if (_isDisplayNonConclusive) return 'Non conclusiva';
    if (screenReplayRisk != null) return 'Nessun indizio display';
    if (_isInvalidResult || _isMediaNotVerified) return 'Non conclusiva';
    return '-';
  }

  String get _effectiveSceneDetail {
    if (sceneDetail != null) return sceneDetail!;
    if (_isStrongDisplayRisk) {
      return 'Piu segnali coerenti indicano una possibile ripresa da schermo.';
    }
    if (_isDisplayNonConclusive) {
      return 'Sono presenti anomalie ambigue, ma non prove sufficienti di ripresa da schermo.';
    }
    if (screenReplayRisk != null) {
      return 'Nessun indizio tecnico sufficiente di ripresa da schermo.';
    }
    if (_isInvalidResult || _isMediaNotVerified) {
      return 'La scena non viene usata per dichiarare il contenuto originale.';
    }
    return '-';
  }

  String? get _effectiveDerivationState {
    if (derivationState != null) return derivationState;
    if (_isForensicResult) return 'Non necessaria';
    if (_isSocialResult) return 'Compatibile';
    if (_isMediaNotVerified) return 'Non verificata';
    return null;
  }

  String get _effectiveDerivationDetail {
    if (derivationDetail != null) return derivationDetail!;
    if (_isForensicResult)
      return 'Il file corrisponde esattamente all originale.';
    if (_isSocialResult) {
      return 'Il file sembra un derivato, una versione ricompressa o rinominata.';
    }
    if (_isMediaNotVerified) {
      return 'Il file non puo essere trattato come derivato verificato del contenuto certificato.';
    }
    return '-';
  }

  String _shortFingerprint(String? value) {
    if (value == null || value.isEmpty) return '-';
    if (value.length <= 18) return value;
    return '${value.substring(0, 10)}...${value.substring(value.length - 8)}';
  }

  Color _axisColor(String? value) {
    final normalized = value?.toLowerCase() ?? '';
    if (normalized.contains('non verificata') ||
        normalized.contains('non originale') ||
        normalized.contains('modificat') ||
        normalized.contains('mismatch')) {
      return Colors.red;
    }
    if (normalized.contains('cautela') ||
        normalized.contains('compatibile') ||
        normalized.contains('conclusiva') ||
        normalized.contains('non presente') ||
        normalized.contains('non raggiungibile') ||
        normalized.contains('non determinata') ||
        normalized.contains('non analizzata') ||
        normalized.contains('incompleta') ||
        normalized.contains('valido') ||
        normalized.contains('derivato')) {
      return Colors.orange;
    }
    if (normalized.contains('verificata') ||
        normalized.contains('integro') ||
        normalized.contains('nessun')) {
      return Colors.green;
    }
    return Colors.grey;
  }

  bool get _signedRealityScene {
    if (displayRiskDecision != 'NO_DISPLAY_EVIDENCE') return false;
    final cert = certificate;
    final claims = cert?['claims'];
    final live = claims is Map ? claims['liveScreenProbe'] : null;
    if (live is! Map) return false;
    final reason = live['reason']?.toString() ?? '';
    return live['sceneClass'] == 'REALITY' &&
        live['displayRiskDecision'] == 'NO_DISPLAY_EVIDENCE' &&
        (reason.contains('MULTI_DEPTH_PARALLAX_DETECTED') ||
            reason.contains(
              'GEOMETRIC_REALITY_OVERRIDES_PLANAR_DISPLAY_HYPOTHESIS',
            ));
  }

  String _verificationAxisSubtitle(String axis) {
    switch (axis) {
      case 'provenance':
        return _v('provenanceHint');
      case 'integrity':
        return _v('integrityHint');
      case 'scene':
        return _v('sceneHint');
      case 'derivation':
        return _v('derivationHint');
      default:
        return '';
    }
  }

  String _localizedAxisState(String axis, String? raw) {
    final value = (raw ?? '').toLowerCase();
    if (axis == 'scene' && _signedRealityScene) return _v('realityDetected');
    if (axis == 'provenance' && value.contains('verificat'))
      return _v('verified');
    if (axis == 'integrity' &&
        value.contains('originale') &&
        value.contains('integro'))
      return _v('originalIntact');
    if (axis == 'integrity' && value.contains('derivato'))
      return _v('compatibleDerivative');
    if (axis == 'scene' &&
        (value.contains('forte rischio') || value.contains('display')))
      return _v('screenRisk');
    if (axis == 'scene' && value.contains('conclusiva'))
      return _v('sceneUncertain');
    if (axis == 'scene' && value.contains('nessun'))
      return _v('noScreenEvidence');
    if (axis == 'derivation' && value.contains('non necessaria'))
      return _v('derivationNotNeeded');
    if (axis == 'derivation' && value.contains('compatibile'))
      return _v('compatible');
    if (value.contains('non verificata')) return _v('notVerified');
    if (value.contains('non determinata')) return _v('notDetermined');
    if (value.contains('non analizzata')) return _v('notAnalyzed');
    return raw ?? '-';
  }

  String _localizedAxisDetail(String axis) {
    if (axis == 'scene' && _signedRealityScene) return _v('realityDetail');
    if (axis == 'provenance') return _v('provenanceOkDetail');
    if (axis == 'integrity')
      return _isForensicResult ? _v('originalDetail') : _v('derivedDetail');
    if (axis == 'scene') {
      if (_isStrongDisplayRisk) return _v('screenDetail');
      if (_isDisplayNonConclusive) return _v('uncertainDetail');
      return _v('noScreenDetail');
    }
    if (axis == 'derivation')
      return _isForensicResult
          ? _v('originalDerivationDetail')
          : _v('derivedDerivationDetail');
    return '-';
  }

  String get _publicResultTitle {
    if (_isForensicResult) return _v('forensicOk');
    if (_isSocialResult) return _v('socialOk');
    if ((result ?? '').contains('REGISTRY NOT FOUND'))
      return _v('registryNotFound');
    if ((result ?? '').contains('REGISTRY UNAVAILABLE'))
      return _v('registryUnavailable');
    return _v('verificationIncomplete');
  }

  String get _publicResultDetail {
    if (_isForensicResult) return _v('forensicOkDetail');
    if (_isSocialResult) return _v('socialOkDetail');
    final value = result ?? '';
    if (value.contains('REGISTRY NOT FOUND')) return _v('registryNotFound');
    if (value.contains('REGISTRY UNAVAILABLE') ||
        value.contains('REGISTRY ERROR')) {
      return _v('registryUnavailable');
    }
    if (_isInvalidResult || _isMediaNotVerified) return _v('notVerified');
    return _v('verificationIncomplete');
  }

  bool get _hasSevereVerificationIssue =>
      _isInvalidResult || _isMediaNotVerified || _isStrongDisplayRisk;

  bool get _hasIntermediateVerificationIssue =>
      !_hasSevereVerificationIssue &&
      (_isRegistryWarningResult ||
          _isDisplayNonConclusive ||
          isScreenReplayWarning);

  Color get _verificationResultColor {
    if (result == null) return Colors.grey;
    if (_hasSevereVerificationIssue) return Colors.red;
    if (_hasIntermediateVerificationIssue) return Colors.orange;
    if (isVerified) return Colors.green;
    return Colors.red;
  }

  IconData get _verificationResultIcon {
    if (result == null) return Icons.cloud_sync;
    if (_hasSevereVerificationIssue) return Icons.error;
    if (_hasIntermediateVerificationIssue) return Icons.warning_amber;
    if (isVerified) return Icons.verified;
    return Icons.error;
  }

  Map<dynamic, dynamic>? get _signedMlDiagnostics {
    final cert = certificate;
    final claims = cert?['claims'];
    if (claims is! Map) return null;
    final ml = claims['mlScreenReplayAnalysis'];
    return ml is Map ? ml : null;
  }

  String _diagnosticValue(Object? value) {
    final text = value?.toString();
    return text == null || text.isEmpty ? '-' : text;
  }

  String get _fullTechnicalDiagnostics {
    final ml = _signedMlDiagnostics;
    return 'HCV trust: ${_diagnosticValue(hcvTrustLevel)}\n'
        'Live capture trust: ${_diagnosticValue(liveCaptureTrust)}\n'
        'Scene authenticity: ${_diagnosticValue(sceneAuthenticity)}\n'
        'Synthetic risk: ${_diagnosticValue(syntheticRisk)}\n'
        'AI proof level: ${_diagnosticValue(aiProofLevel)}\n'
        '\nDISPLAY FUSION\n'
        'Decision: ${_diagnosticValue(displayRiskDecision)}\n'
        'Risk: ${_diagnosticValue(screenReplayRisk)}\n'
        'Score: ${_diagnosticValue(screenReplayRiskScore)}\n'
        '\nPASSIVE VIDEO/IMAGE ANALYSIS\n'
        'Segments analyzed: ${_diagnosticValue(screenReplaySegmentsAnalyzed)}\n'
        'Worst segment second: ${_diagnosticValue(screenReplayWorstSecond)}\n'
        'Local temporal flicker: ${_diagnosticValue(localTemporalFlickerScore)}\n'
        'Refresh band: ${_diagnosticValue(refreshBandScore)}\n'
        'Pixel-grid uniformity: ${_diagnosticValue(pixelGridUniformityScore)}\n'
        '\nLIVE SCREEN PROBE\n'
        'Analysis status: ${_diagnosticValue(liveProbeAnalysisStatus)}\n'
        'Frames analyzed: ${_diagnosticValue(liveProbeFrames)}\n'
        'Risk: ${_diagnosticValue(liveProbeRisk)}\n'
        'Reason: ${_diagnosticValue(liveProbeReason)}\n'
        'Error: ${_diagnosticValue(liveProbeError)}\n'
        'Local temporal flicker: ${_diagnosticValue(liveProbeLocalFlickerScore)}\n'
        'Refresh band: ${_diagnosticValue(liveProbeRefreshBandScore)}\n'
        'Fine stripe: ${_diagnosticValue(liveProbeFineStripeScore)}\n'
        'Fine grid: ${_diagnosticValue(liveProbeFineGridScore)}\n'
        'Moiré frequency: ${_diagnosticValue(liveProbeMoireFrequencyScore)}\n'
        'Dynamic challenge: ${_diagnosticValue(liveProbeDynamicChallengeScore)}\n'
        'Persistent pattern: ${_diagnosticValue(liveProbePersistentPatternScore)}\n'
        'Optical corroborated trace: ${_diagnosticValue(liveProbeOpticalCorroboratedTrace)}\n'
        'Moiré trace: ${_diagnosticValue(liveProbeMoireFrequencyTrace)}\n'
        'Dynamic screen challenge trace: ${_diagnosticValue(liveProbeDynamicScreenChallengeTrace)}\n'
        'Uncorroborated display pattern: ${_diagnosticValue(liveProbeUncorroboratedDisplayPattern)}\n'
        '\nML SCREEN REPLAY\n'
        'Analysis status: ${_diagnosticValue(ml?['analysisStatus'])}\n'
        'Model source: ${_diagnosticValue(ml?['modelSource'])}\n'
        'Model version: ${_diagnosticValue(ml?['modelVersion'])}\n'
        'TFLite runtime: ${_diagnosticValue(ml?['tfliteRuntimeVersion'])}\n'
        'Model SHA-256: ${_diagnosticValue(ml?['modelSha256'])}\n'
        'Predicted class: ${_diagnosticValue(ml?['predictedClass'])}\n'
        'Predicted confidence: ${_diagnosticValue(ml?['predictedClassConfidence'])}\n'
        'Screen probability: ${_diagnosticValue(ml?['screenProbability'])}\n'
        'Risk: ${_diagnosticValue(ml?['screenReplayRisk'])}\n'
        'Risk score: ${_diagnosticValue(ml?['screenReplayRiskScore'])}\n'
        'ML decision: ${_diagnosticValue(ml?['displayRiskDecision'])}\n'
        'Reason: ${_diagnosticValue(ml?['reason'])}\n'
        'Error: ${_diagnosticValue(ml?['error'])}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SigillumTheme.deep,
      appBar: AppBar(
        backgroundColor: SigillumTheme.panel,
        foregroundColor: SigillumTheme.ink,
        elevation: 0,
        title: Text(_t('verifyContentHeading')),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _verificationResultIcon,
                size: 72,
                color: _verificationResultColor,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: idController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'HCV-ID',
                  hintText: 'HCV-DE27F535',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: loading ? null : pickMedia,
                child: Text(_v('selectOriginal')),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: loading ? null : verifyFromRegistry,
                child: Text(loading ? _v('verifying') : _v('verifyRegistry')),
              ),
              const SizedBox(height: 20),
              Text(status, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                _v('registryHelper'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              if (_hasVerificationAxes) ...[
                const SizedBox(height: 18),
                _VerificationAxisCard(
                  icon: Icons.badge_outlined,
                  title: _v('provenance'),
                  subtitle: _verificationAxisSubtitle('provenance'),
                  value: _localizedAxisState(
                    'provenance',
                    _effectiveProvenanceState,
                  ),
                  detail: _localizedAxisDetail('provenance'),
                  color: _axisColor(_effectiveProvenanceState),
                ),
                const SizedBox(height: 10),
                _VerificationAxisCard(
                  icon: Icons.verified_user_outlined,
                  title: _v('integrity'),
                  subtitle: _verificationAxisSubtitle('integrity'),
                  value: _localizedAxisState(
                    'integrity',
                    _effectiveIntegrityState,
                  ),
                  detail: _localizedAxisDetail('integrity'),
                  color: _axisColor(_effectiveIntegrityState),
                ),
                const SizedBox(height: 10),
                _VerificationAxisCard(
                  icon: Icons.visibility_outlined,
                  title: _v('scene'),
                  subtitle: _verificationAxisSubtitle('scene'),
                  value: _localizedAxisState('scene', _effectiveSceneState),
                  detail: _localizedAxisDetail('scene'),
                  color: _isStrongDisplayRisk
                      ? Colors.red
                      : _isDisplayNonConclusive
                      ? Colors.orange
                      : _axisColor(_effectiveSceneState),
                ),
                if (_effectiveDerivationState != null) ...[
                  const SizedBox(height: 10),
                  _VerificationAxisCard(
                    icon: Icons.account_tree_outlined,
                    title: _v('derivation'),
                    subtitle: _verificationAxisSubtitle('derivation'),
                    value: _localizedAxisState(
                      'derivation',
                      _effectiveDerivationState,
                    ),
                    detail: _localizedAxisDetail('derivation'),
                    color: _axisColor(_effectiveDerivationState),
                  ),
                ],
              ],
              if (result != null) ...[
                const SizedBox(height: 20),
                Text(
                  _publicResultTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _verificationResultColor,
                  ),
                ),
              ],
              if (creatorName != null ||
                  trustLevel != null ||
                  identityAssuranceLevel != null ||
                  legalIdentityStatus != null ||
                  identityFingerprint != null ||
                  creatorKeyFingerprint != null ||
                  contentType != null) ...[
                const SizedBox(height: 16),
                Text(
                  '${_t('declaredName')}: ${creatorName ?? '-'}\n'
                  '${_t('technicalProof')}: ${trustLevel ?? '-'}\n'
                  '${_t('identityAssurance')}: ${identityAssuranceLevel ?? '-'}\n'
                  '${_t('legalIdentity')}: ${legalIdentityStatus ?? '-'}\n'
                  '${_t('technicalIdentityFingerprint')}: ${_shortFingerprint(identityFingerprint)}\n'
                  '${_t('deviceKeyFingerprint')}: ${_shortFingerprint(creatorKeyFingerprint)}\n'
                  'Type: ${contentType ?? '-'}',
                  textAlign: TextAlign.center,
                ),
              ],
              if (hcvTrustLevel != null ||
                  liveCaptureTrust != null ||
                  screenReplayRisk != null) ...[
                const SizedBox(height: 14),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.90),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: SigillumTheme.border),
                  ),
                  child: ExpansionTile(
                    title: Text(
                      _v('technicalDetails'),
                      style: const TextStyle(
                        color: SigillumTheme.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                    children: [
                      Text(
                        _fullTechnicalDiagnostics,
                        textAlign: TextAlign.left,
                        style: const TextStyle(
                          color: SigillumTheme.muted,
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _VerificationAxisCard extends StatelessWidget {
  const _VerificationAxisCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.detail,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final String detail;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: SigillumTheme.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12280D5F),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    color: SigillumTheme.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: SigillumTheme.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    color: color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  detail,
                  style: const TextStyle(
                    color: SigillumTheme.ink,
                    fontSize: 14,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
