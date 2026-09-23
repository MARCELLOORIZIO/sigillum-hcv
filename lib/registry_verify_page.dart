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
import 'hcv_spatial_fingerprint_v2.dart';
import 'hcv_audio_fingerprint.dart';
import 'hcv_media_id_ocr.dart';
import 'sigillum_localization.dart';
import 'sigillum_theme.dart';
import 'verification_ui_copy.dart';
import 'registry_verify_copy.dart';

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
  final signedDecision =
      evidence is Map ? evidence['decision']?.toString() : null;
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

enum HCVSocialFingerprintClaimState {
  usable,
  legacyMissing,
  modernInvalid,
}

HCVSocialFingerprintClaimState resolveHCVSocialFingerprintClaimState(
  Map<dynamic, dynamic> claims, {
  required String mediaType,
}) {
  final requiresModernFingerprint = claims['socialVerification'] == true;
  final rawFingerprint = claims['socialFingerprint'];
  if (rawFingerprint is! Map) {
    return requiresModernFingerprint
        ? HCVSocialFingerprintClaimState.modernInvalid
        : HCVSocialFingerprintClaimState.legacyMissing;
  }

  final algorithm = rawFingerprint['algorithm']?.toString() ?? '';
  final shaLikeFingerprint = RegExp(r'^[a-fA-F0-9]{64}$');

  bool valid = false;
  if (mediaType == 'photo') {
    final imageHash = rawFingerprint['imageHash']?.toString() ?? '';
    valid = algorithm == 'SIGILLUM_SOCIAL_IMAGE_AHASH_V1' &&
        shaLikeFingerprint.hasMatch(imageHash);
  } else if (mediaType == 'video') {
    final frameHashes = rawFingerprint['frameHashes'];
    valid = algorithm == 'SIGILLUM_SOCIAL_AHASH_V1' &&
        frameHashes is List &&
        frameHashes.isNotEmpty &&
        frameHashes.every(
          (value) => shaLikeFingerprint.hasMatch(value.toString()),
        );
  }

  if (valid &&
      mediaType == 'photo' &&
      rawFingerprint.containsKey('spatialFingerprint') &&
      !HCVSpatialFingerprintV2.isValid(
        rawFingerprint['spatialFingerprint'],
      )) {
    return HCVSocialFingerprintClaimState.modernInvalid;
  }
  if (valid &&
      mediaType == 'video' &&
      rawFingerprint.containsKey('spatialFrameFingerprints')) {
    final spatial = rawFingerprint['spatialFrameFingerprints'];
    final frames = rawFingerprint['frameHashes'] as List;
    if (spatial is! List ||
        spatial.length != frames.length ||
        spatial.any((entry) => !HCVSpatialFingerprintV2.isValid(entry))) {
      return HCVSocialFingerprintClaimState.modernInvalid;
    }
  }
  if (valid) return HCVSocialFingerprintClaimState.usable;
  return requiresModernFingerprint
      ? HCVSocialFingerprintClaimState.modernInvalid
      : HCVSocialFingerprintClaimState.legacyMissing;
}

bool? resolveHCVSocialFingerprintAvailability(
  Map<dynamic, dynamic> claims, {
  required String mediaType,
}) {
  switch (resolveHCVSocialFingerprintClaimState(
    claims,
    mediaType: mediaType,
  )) {
    case HCVSocialFingerprintClaimState.usable:
      return true;
    case HCVSocialFingerprintClaimState.legacyMissing:
      return null;
    case HCVSocialFingerprintClaimState.modernInvalid:
      return false;
  }
}

enum HCVAudioFingerprintClaimState {
  usable,
  legacyMissing,
  modernInvalid,
}

HCVAudioFingerprintClaimState resolveHCVAudioFingerprintClaimState(
  Map<dynamic, dynamic> claims,
) {
  final social = claims['socialFingerprint'];
  if (social is! Map || !social.containsKey('audioFingerprintPolicy')) {
    return HCVAudioFingerprintClaimState.legacyMissing;
  }
  if (social['audioFingerprintPolicy'] != HCVAudioFingerprint.policy) {
    return HCVAudioFingerprintClaimState.modernInvalid;
  }
  final audio = social['audioFingerprint'];
  if (audio is! Map || !HCVAudioFingerprint.isValidFingerprint(audio)) {
    return HCVAudioFingerprintClaimState.modernInvalid;
  }
  return HCVAudioFingerprintClaimState.usable;
}

bool? resolveHCVAudioFingerprintAvailability(Map<dynamic, dynamic> claims) {
  switch (resolveHCVAudioFingerprintClaimState(claims)) {
    case HCVAudioFingerprintClaimState.usable:
      return true;
    case HCVAudioFingerprintClaimState.legacyMissing:
      return null;
    case HCVAudioFingerprintClaimState.modernInvalid:
      return false;
  }
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
  String _r(String key) => RegistryVerifyCopy.t(widget.languageCode, key);

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

    final match =
        RegExp(r'HCV-[A-F0-9]{16}(?![A-F0-9])').firstMatch(normalized);
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

      final command = "-y -ss $time -i '$videoPath' "
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

  Future<MapEntry<String, Map<String, dynamic>>> _fetchCertificateExact(
    String hcvId,
  ) async {
    return MapEntry(hcvId, await registry.fetchCertificate(hcvId));
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

  Future<List<String>> _deepVideoOcrCandidates(String videoPath) async {
    final detections = <String>[];
    const times = <double>[0.2, 0.8];

    for (final seconds in times) {
      String? framePath;
      try {
        framePath = Platform.isIOS
            ? await _extractNativeVideoFrame(videoPath, seconds)
            : await _extractFfmpegVideoFrame(
                videoPath,
                '00:00:0${seconds.toStringAsFixed(1)}',
              );
        if (framePath == null || framePath.isEmpty) continue;

        detections.addAll(
          await HCVMediaIdOcr.extractCandidatesFromImage(framePath),
        );
      } catch (_) {
        // A failed recovery frame must not turn a Registry miss into an error.
      } finally {
        if (framePath != null && framePath.isNotEmpty) {
          try {
            final frame = File(framePath);
            if (await frame.exists()) await frame.delete();
          } catch (_) {}
        }
      }
    }

    return HCVMediaIdOcr.rankConsensusCandidates(detections);
  }

  Future<MapEntry<String, Map<String, dynamic>>>
      _fetchCertificateWithMediaOcrRecovery(String hcvId) async {
    final path = mediaPath;
    if (path == null) {
      return await _fetchCertificateWithLocalRecovery(hcvId);
    }

    final lower = path.toLowerCase();
    final isPhoto = lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png');
    final isVideo = lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.m4v');

    if (!isPhoto && !isVideo) {
      return await _fetchCertificateWithLocalRecovery(hcvId);
    }

    late HCVRegistryException originalNotFound;
    try {
      return await _fetchCertificateExact(hcvId);
    } on HCVRegistryException catch (error) {
      if (error.kind != HCVRegistryFailureKind.notFound) rethrow;
      originalNotFound = error;
    }

    // The expensive recovery path is enabled only after OCR has already found
    // a syntactically valid HCV-ID and Registry returned 404 for that exact ID.
    // This preserves the fast exit for ordinary non-SIGILLUM photos/videos.
    final rankedCandidates = isPhoto
        ? await HCVMediaIdOcr.extractCandidatesFromImage(path)
        : await _deepVideoOcrCandidates(path);

    final attemptedIds = <String>{hcvId};
    final recoveryBases = <String>[hcvId];

    for (final rawCandidate in rankedCandidates) {
      final candidate = rawCandidate.trim().toUpperCase();
      if (!RegExp(r'^HCV-[A-F0-9]{16}$').hasMatch(candidate)) continue;
      if (!recoveryBases.contains(candidate)) recoveryBases.add(candidate);
      if (!attemptedIds.add(candidate)) continue;
      try {
        return await _fetchCertificateExact(candidate);
      } on HCVRegistryException catch (candidateError) {
        if (candidateError.kind == HCVRegistryFailureKind.notFound) continue;
        rethrow;
      }
    }

    // Only after independent OCR readings are absent online, try a bounded set
    // of single-character alternatives (C/0, B/8, E/6). These substitutions
    // are never applied during normal parsing, because all are valid hex.
    final variants = HCVMediaIdOcr.buildRegistryRecoveryVariants(
      recoveryBases,
      maxVariants: 24,
    );
    for (final candidate in variants) {
      if (!attemptedIds.add(candidate)) continue;
      try {
        return await _fetchCertificateExact(candidate);
      } on HCVRegistryException catch (candidateError) {
        if (candidateError.kind == HCVRegistryFailureKind.notFound) continue;
        rethrow;
      }
    }

    // Preserve pending/local-certificate recovery only after the bounded online
    // OCR search. Re-check exactly the IDs already attempted.
    try {
      await registry.retryPendingUploads();
      for (final candidate in attemptedIds) {
        try {
          return await _fetchCertificateExact(candidate);
        } on HCVRegistryException catch (candidateError) {
          if (candidateError.kind == HCVRegistryFailureKind.notFound) continue;
          rethrow;
        }
      }
    } catch (_) {}

    for (final candidate in attemptedIds) {
      final localCertificate = await _findLocalCertificate(candidate);
      if (localCertificate == null) continue;
      try {
        await registry.uploadCertificateFile(localCertificate.path);
        return await _fetchCertificateExact(candidate);
      } catch (_) {}
    }

    throw originalNotFound;
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

    final fingerprintAvailable = resolveHCVSocialFingerprintAvailability(
      claims,
      mediaType: 'video',
    );
    if (fingerprintAvailable != true) return fingerprintAvailable;

    final stored = claims['socialFingerprint'] as Map;
    final storedHashes = stored['frameHashes'] as List;

    try {
      final current =
          await HCVSocialFingerprint().buildVisualFromVideo(mediaPath!);
      final currentHashes = current['frameHashes'];

      if (currentHashes is! List || currentHashes.isEmpty) {
        return false;
      }

      final signedSpatial = stored['spatialFrameFingerprints'];
      if (signedSpatial == null) {
        // Historical V1 aHash can establish resemblance, not an assertion of
        // visual integrity after a particular social transcode.
        return _videoFrameHashesMatch(storedHashes, currentHashes)
            ? null
            : false;
      }
      final currentSpatial = current['spatialFrameFingerprints'];
      if (signedSpatial is! List ||
          currentSpatial is! List ||
          signedSpatial.length != storedHashes.length ||
          currentSpatial.length != currentHashes.length) {
        return false;
      }
      return _videoFrameSpatialHashesMatch(
        storedHashes,
        currentHashes,
        signedSpatial,
        currentSpatial,
      );
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

    final comparableCount =
        expected.length < current.length ? expected.length : current.length;
    final requiredMatches = max(2, (comparableCount * 0.35).ceil());

    return matched >= requiredMatches;
  }

  bool _videoFrameSpatialHashesMatch(
    List expectedHashes,
    List currentHashes,
    List expectedSpatial,
    List currentSpatial,
  ) {
    final used = <int>{};
    var matched = 0;
    for (var e = 0; e < expectedHashes.length; e++) {
      var bestIndex = -1;
      var bestDistance = 9999;
      for (var i = 0; i < currentHashes.length; i++) {
        if (used.contains(i)) continue;
        final distance = _hexDistance(
          expectedHashes[e].toString(),
          currentHashes[i].toString(),
        );
        if (distance > 96 ||
            distance >= bestDistance ||
            !HCVSpatialFingerprintV2.matches(
              expectedSpatial[e],
              currentSpatial[i],
            )) {
          continue;
        }
        bestDistance = distance;
        bestIndex = i;
      }
      if (bestIndex != -1) {
        used.add(bestIndex);
        matched++;
      }
    }
    final comparable = min(expectedHashes.length, currentHashes.length);
    final required = max(2, (comparable * 0.60).ceil());
    return matched >= required;
  }

  Future<bool?> _matchesCertifiedAudioFingerprint(
    Map<String, dynamic> cert,
  ) async {
    if (mediaPath == null) return null;
    final lowerPath = mediaPath!.toLowerCase();
    if (!lowerPath.endsWith('.mp4') &&
        !lowerPath.endsWith('.mov') &&
        !lowerPath.endsWith('.m4v')) {
      return null;
    }

    final claims = cert['claims'];
    if (claims is! Map) return null;
    final availability = resolveHCVAudioFingerprintAvailability(claims);
    if (availability != true) return availability;

    final social = claims['socialFingerprint'] as Map;
    final stored = Map<String, dynamic>.from(
      social['audioFingerprint'] as Map,
    );
    try {
      final current = await HCVAudioFingerprint.buildFromVideo(mediaPath!);
      return HCVAudioFingerprint.matches(stored, current);
    } catch (_) {
      return false;
    }
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

    final fingerprintAvailable = resolveHCVSocialFingerprintAvailability(
      claims,
      mediaType: 'photo',
    );
    if (fingerprintAvailable != true) return fingerprintAvailable;

    final stored = claims['socialFingerprint'] as Map;
    final expected = stored['imageHash']!.toString();

    try {
      final current = await HCVSocialFingerprint().buildFromImage(mediaPath!);
      final actual = current['imageHash']?.toString();

      if (actual == null || actual.isEmpty) {
        return false;
      }

      if (_hexDistance(expected, actual) > 72) return false;
      final signedSpatial = stored['spatialFingerprint'];
      if (signedSpatial == null) return null; // V1 is visual similarity only.
      return HCVSpatialFingerprintV2.matches(
        signedSpatial,
        current['spatialFingerprint'],
      );
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
        status = _r('quickCheck');
        hcvIdDetectedByOcr = false;
      });

      final file = File(path);
      if (!await file.exists()) {
        if (!mounted) return;
        setState(() {
          result = 'NOT ANALYZED';
          status = _r('fileUnavailable');
        });
        return;
      }

      final suppliedId = widget.initialHcvId?.trim().toUpperCase();
      final detectedId = suppliedId != null &&
              RegExp(r'^HCV-[A-F0-9]{16}$').hasMatch(suppliedId)
          ? suppliedId
          : await detectHcvIdFromMediaPath(path);

      if (!mounted) return;

      if (detectedId == null || detectedId.isEmpty) {
        setState(() {
          result = null;
          status = _r('notCertified');
        });
        return;
      }

      setState(() {
        hcvIdDetectedByOcr = true;
        idController.text = detectedId;
        status = _r('idDetectedAuto');
      });

      await verifyFromRegistry();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        result = 'NOT ANALYZED';
        status = _r('autoIncomplete');
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
        status = _r('iosImportFailed');
      });
      return;
    }

    final lowerPath = path.toLowerCase();

    if (lowerPath.endsWith('.hcv') || lowerPath.endsWith('.hcvpack')) {
      setState(() {
        mediaPath = null;
        result = 'INVALID';
        status = _r('selectOriginalNotPack');
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
          status = _r('ocrDetectedMedia');
        });
      }

      if (ocrId != null) {
        idController.text = ocrId;

        setState(() {
          status = _r('ocrDetectedMedia');
        });
      }
    }

    setState(() {
      mediaPath = path;
      result = null;

      status = idController.text.trim().isNotEmpty
          ? _r('idDetectedPressVerify')
          : _r('fileSelectedPressVerify');
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
        status = _r('enterId');
      });

      return;
    }

    if (mediaPath == null) {
      setState(() {
        status = _r('selectOriginal');
      });

      return;
    }

    setState(() {
      loading = true;

      result = null;

      status = _r('downloadingCertificate');
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
      final resolved = await _fetchCertificateWithMediaOcrRecovery(hcvId);
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
          screenReplayWorstSecond =
              screenReplayAnalysis['worstSegmentSecond']?.toString();
          localTemporalFlickerScore =
              screenReplayAnalysis['localTemporalFlickerScore']?.toString();
          refreshBandScore =
              screenReplayAnalysis['refreshBandScore']?.toString();
          pixelGridUniformityScore =
              screenReplayAnalysis['pixelGridUniformityScore']?.toString();
        }
        final liveScreenProbe = claims['liveScreenProbe'];
        if (liveScreenProbe is Map) {
          liveProbeFrames = liveScreenProbe['framesAnalyzed']?.toString();
          liveProbeRisk = liveScreenProbe['screenReplayRisk']?.toString();
          liveProbeAnalysisStatus =
              liveScreenProbe['analysisStatus']?.toString();
          liveProbeReason = liveScreenProbe['reason']?.toString();
          liveProbeError = liveScreenProbe['error']?.toString();
          liveProbeLocalFlickerScore =
              liveScreenProbe['localTemporalFlickerScore']?.toString();
          liveProbeRefreshBandScore =
              liveScreenProbe['refreshBandScore']?.toString();
          liveProbeFineStripeScore =
              liveScreenProbe['fineStripeScore']?.toString();
          liveProbeFineGridScore = liveScreenProbe['fineGridScore']?.toString();
          liveProbeMoireFrequencyScore =
              liveScreenProbe['moireFrequencyScore']?.toString();
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

          status = _r('signatureInvalid');

          result = 'INVALID';

          certificate = cert;
        });

        return;
      }

      final content = cert['content'];

      if (content is! Map<String, dynamic>) {
        setState(() {
          loading = false;

          status = _r('bindingMissing');

          result = 'INVALID';

          certificate = cert;
        });

        return;
      }

      final mediaFile = File(mediaPath!);

      if (!await mediaFile.exists()) {
        setState(() {
          loading = false;

          status = _r('mediaMissing');

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
        creatorKeyFingerprint =
            identity['devicePublicKeyFingerprint']?.toString();
      }

      contentType = contentTypeForVerification;

      final forensicVerified = actualHash == expectedHash;
      final videoFingerprintMatches = await _matchesCertifiedVideoFingerprint(
        cert,
      );
      final audioFingerprintMatches = await _matchesCertifiedAudioFingerprint(
        cert,
      );
      final imageFingerprintMatches = await _matchesCertifiedImageFingerprint(
        cert,
      );

      setState(() {
        loading = false;

        certificate = cert;

        void markLimited() {
          status = _r('socialLimitedStatus');
          result = 'SOCIAL LIMITED';
          _setVerificationAxes(
            provenance: 'Verificata',
            provenanceDetail:
                'Certificato Registry valido; HCV-ID associato al file.',
            integrity: 'Non conclusiva',
            integrityDetail: _r('socialLimitedDetail'),
            scene: 'Non conclusiva',
            sceneDetail:
                'La somiglianza V1 non prova che il derivato non sia stato modificato.',
            derivation: 'Non conclusiva',
            derivationDetail: _r('socialLimitedDetail'),
          );
        }

        void markVerified(String cleanStatus, String cleanResult) {
          final exactOriginal = cleanResult.startsWith('FORENSIC');
          final sceneWarning = _isStrongDisplayRisk;
          final sceneUncertain = _isDisplayNonConclusive;
          _setVerificationAxes(
            provenance: 'Verificata',
            provenanceDetail:
                'Certificato Registry valido, identita tecnica e contenuto collegati.',
            integrity:
                exactOriginal ? 'Originale integro' : 'Derivato compatibile',
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
                '$cleanStatus\n\n${_r('sceneWarning').replaceAll('{risk}', screenReplayRisk ?? '-')}';

            result = cleanResult;
          } else {
            status = cleanStatus;
            result = cleanResult;
          }
        }

        if (forensicVerified) {
          markVerified(
            _r('forensicStatus'),
            'FORENSIC VERIFIED OK',
          );
        } else if (socialTextVerified) {
          markVerified(
            _r('socialTextStatus'),
            'SOCIAL VERIFIED OK',
          );
        } else {
          status = _r('genericDerived');

          final hcvIdWasDetectedInMedia = hcvIdDetectedByOcr;
          final hcvIdProvided = idController.text.trim().isNotEmpty;

          if (contentType == 'video' &&
              videoFingerprintMatches == true &&
              audioFingerprintMatches == false) {
            status = hcvIdWasDetectedInMedia
                ? _r('audioMismatchDetected')
                : _r('audioMismatchProvided');
            result = 'ID VALID / MEDIA NOT VERIFIED';
          } else if (contentType == 'video' &&
              videoFingerprintMatches == true) {
            markVerified(
              audioFingerprintMatches == true
                  ? (hcvIdWasDetectedInMedia
                      ? _r('videoBothDetected')
                      : _r('videoBothProvided'))
                  : (hcvIdWasDetectedInMedia
                      ? _r('videoLegacyAudioDetected')
                      : _r('videoLegacyAudioProvided')),
              'SOCIAL VERIFIED OK',
            );
          } else if ((hcvIdWasDetectedInMedia || hcvIdProvided) &&
              contentType == 'video' &&
              videoFingerprintMatches == null) {
            markLimited();
          } else if ((hcvIdWasDetectedInMedia || hcvIdProvided) &&
              contentType == 'video' &&
              videoFingerprintMatches == false) {
            status = hcvIdWasDetectedInMedia
                ? _r('videoMismatchDetected')
                : _r('videoMismatchProvided');

            result = 'ID VALID / MEDIA NOT VERIFIED';
          } else if (contentType == 'photo' &&
              imageFingerprintMatches == true) {
            markVerified(
              hcvIdWasDetectedInMedia
                  ? _r('photoCompatibleDetected')
                  : _r('photoCompatibleProvided'),
              'SOCIAL VERIFIED OK',
            );
          } else if ((hcvIdWasDetectedInMedia || hcvIdProvided) &&
              contentType == 'photo' &&
              imageFingerprintMatches == null) {
            markLimited();
          } else if ((hcvIdWasDetectedInMedia || hcvIdProvided) &&
              contentType == 'photo' &&
              imageFingerprintMatches == false) {
            status = hcvIdWasDetectedInMedia
                ? _r('photoMismatchDetected')
                : _r('photoMismatchProvided');

            result = 'ID VALID / MEDIA NOT VERIFIED';
          } else if (hcvIdWasDetectedInMedia && contentType != 'text') {
            markLimited();
          } else {
            status = _r('idNotDetected');

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
            status = _r('registryNotFoundDetail');
            result = 'REGISTRY NOT FOUND';
            _setVerificationAxes(
              provenance: 'Non presente online',
              provenanceDetail:
                  'Il Registry non contiene ancora questo HCV-ID. Il file non viene dichiarato alterato.',
              integrity: 'Non determinata',
              integrityDetail:
                  'Senza il certificato online non e possibile confrontare firma e contenuto.',
              scene: 'Non analizzata',
              sceneDetail:
                  'Il controllo della scena non viene eseguito senza certificato.',
              derivation: null,
              derivationDetail: null,
            );
            break;
          case HCVRegistryFailureKind.unavailable:
          case HCVRegistryFailureKind.server:
            status = _r('registryUnavailableDetail');
            result = 'REGISTRY UNAVAILABLE';
            _setVerificationAxes(
              provenance: 'Registry non raggiungibile',
              provenanceDetail:
                  'La verifica online non e stata completata per un problema di rete o del server.',
              integrity: 'Non determinata',
              integrityDetail: 'Nessun verdetto di modifica e stato emesso.',
              scene: 'Non analizzata',
              sceneDetail:
                  'Il controllo della scena non viene eseguito senza certificato.',
              derivation: null,
              derivationDetail: null,
            );
            break;
          case HCVRegistryFailureKind.invalidResponse:
            status =
                _r('registryInvalidResponse').replaceAll('{error}', e.message);
            result = 'REGISTRY ERROR';
            _setVerificationAxes(
              provenance: 'Verifica online incompleta',
              provenanceDetail:
                  'Il Registry ha risposto, ma la risposta non consente una verifica affidabile.',
              integrity: 'Non determinata',
              integrityDetail: 'Nessun verdetto di modifica e stato emesso.',
              scene: 'Non analizzata',
              sceneDetail:
                  'Il controllo della scena non viene eseguito senza certificato valido.',
              derivation: null,
              derivationDetail: null,
            );
            break;
          case HCVRegistryFailureKind.invalidCertificate:
            status =
                _r('invalidLocalCertificate').replaceAll('{error}', e.message);
            result = 'INVALID';
            _setVerificationAxes(
              provenance: 'Non verificata',
              provenanceDetail:
                  'Il certificato locale non supera i controlli strutturali.',
              integrity: 'Non verificata',
              integrityDetail: 'Integrita non dimostrata.',
              scene: 'Non analizzata',
              sceneDetail:
                  'Il controllo della scena non viene usato per questo verdetto.',
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
        status =
            _r('unexpectedRegistryError').replaceAll('{error}', e.toString());
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
    final mlConfidence =
        ml is Map ? _asDouble(ml['predictedClassConfidence']) : 0.0;
    final mlScreenProbability =
        ml is Map ? _asDouble(ml['screenProbability']) : 1.0;
    final passiveScore = passive is Map
        ? (passive['screenReplayRiskScore'] as num?)?.toInt()
        : null;
    final liveSignals = liveProbe['signals'];
    final liveFineGrid = _asDouble(liveProbe['fineGridScore']);
    final liveFineStripe = _asDouble(liveProbe['fineStripeScore']);
    final livePersistent = _asDouble(liveProbe['persistentPatternScore']);
    final liveDynamic = _asDouble(liveProbe['dynamicChallengeScore']);
    final closeDisplaySpatialTrace = (liveSignals is Map &&
            liveSignals['closeDisplaySpatialTrace'] == true) ||
        (liveSignals is Map &&
            liveSignals['dynamicScreenChallengeTrace'] == true &&
            liveFineGrid > 0.85 &&
            liveFineStripe < 0.42 &&
            livePersistent > 0.85 &&
            liveDynamic < 0.18);
    final confirmedTemporalTrace =
        liveSignals is Map && liveSignals['confirmedDisplayTrace'] == true;
    final mlSaysReality = mlClass != null &&
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
      displayRiskDecision =
          downgradedScore >= 45 ? 'NON_CONCLUSIVE' : 'NO_DISPLAY_EVIDENCE';
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

  bool get _isSocialLimited => result == 'SOCIAL LIMITED';

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
        value.contains('integro')) return _v('originalIntact');
    if (axis == 'integrity' && value.contains('derivato'))
      return _v('compatibleDerivative');
    if (axis == 'scene' && value.contains('nessun'))
      return _v('noScreenEvidence');
    if (axis == 'scene' && value.contains('conclusiva'))
      return _v('sceneUncertain');
    if (axis == 'scene' && value.contains('forte rischio'))
      return _v('screenRisk');
    if (axis == 'derivation' && value.contains('non necessaria'))
      return _v('derivationNotNeeded');
    if (axis == 'derivation' && value.contains('compatibile'))
      return _v('compatible');
    if (value.contains('non verificata')) return _v('notVerified');
    if (value.contains('non conclusiva')) return _v('notDetermined');
    if (value.contains('non determinata')) return _v('notDetermined');
    if (value.contains('non analizzata')) return _v('notAnalyzed');
    return raw ?? '-';
  }

  String _localizedAxisDetail(String axis) {
    if (axis == 'scene' && _signedRealityScene) return _v('realityDetail');
    if (axis == 'provenance') return _v('provenanceOkDetail');
    if (axis == 'integrity') {
      if (_isSocialLimited) return _r('socialLimitedDetail');
      return _isForensicResult ? _v('originalDetail') : _v('derivedDetail');
    }
    if (axis == 'scene') {
      if (_isStrongDisplayRisk) return _v('screenDetail');
      if (_isDisplayNonConclusive) return _v('uncertainDetail');
      return _v('noScreenDetail');
    }
    if (axis == 'derivation') {
      if (_isSocialLimited) return _r('socialLimitedDetail');
      return _isForensicResult
          ? _v('originalDerivationDetail')
          : _v('derivedDerivationDetail');
    }
    return '-';
  }

  String get _publicResultTitle {
    if (_isForensicResult) return _v('forensicOk');
    if (_isSocialLimited) return _r('socialLimitedTitle');
    if (_isSocialResult) return _v('socialOk');
    if ((result ?? '').contains('REGISTRY NOT FOUND'))
      return _v('registryNotFound');
    if ((result ?? '').contains('REGISTRY UNAVAILABLE'))
      return _v('registryUnavailable');
    return _v('verificationIncomplete');
  }

  String get _publicResultDetail {
    if (_isForensicResult) return _v('forensicOkDetail');
    if (_isSocialLimited) return _r('socialLimitedDetail');
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
          _isSocialLimited ||
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
    return '${_r('techHcvTrust')}: ${_diagnosticValue(hcvTrustLevel)}\n'
        '${_r('techLiveTrust')}: ${_diagnosticValue(liveCaptureTrust)}\n'
        '${_r('techSceneAuthenticity')}: ${_diagnosticValue(sceneAuthenticity)}\n'
        '${_r('techSyntheticRisk')}: ${_diagnosticValue(syntheticRisk)}\n'
        '${_r('techAiProof')}: ${_diagnosticValue(aiProofLevel)}\n'
        '\n${_r('techDisplayFusion')}\n'
        '${_r('techDecision')}: ${_diagnosticValue(displayRiskDecision)}\n'
        '${_r('techRisk')}: ${_diagnosticValue(screenReplayRisk)}\n'
        '${_r('techScore')}: ${_diagnosticValue(screenReplayRiskScore)}\n'
        '\n${_r('techPassive')}\n'
        '${_r('techSegments')}: ${_diagnosticValue(screenReplaySegmentsAnalyzed)}\n'
        '${_r('techWorstSecond')}: ${_diagnosticValue(screenReplayWorstSecond)}\n'
        '${_r('techLocalFlicker')}: ${_diagnosticValue(localTemporalFlickerScore)}\n'
        '${_r('techRefreshBand')}: ${_diagnosticValue(refreshBandScore)}\n'
        '${_r('techPixelGrid')}: ${_diagnosticValue(pixelGridUniformityScore)}\n'
        '\n${_r('techLiveProbe')}\n'
        '${_r('techAnalysisStatus')}: ${_diagnosticValue(liveProbeAnalysisStatus)}\n'
        '${_r('techFrames')}: ${_diagnosticValue(liveProbeFrames)}\n'
        '${_r('techRisk')}: ${_diagnosticValue(liveProbeRisk)}\n'
        '${_r('techReason')}: ${_diagnosticValue(liveProbeReason)}\n'
        '${_r('techError')}: ${_diagnosticValue(liveProbeError)}\n'
        '${_r('techLocalFlicker')}: ${_diagnosticValue(liveProbeLocalFlickerScore)}\n'
        '${_r('techRefreshBand')}: ${_diagnosticValue(liveProbeRefreshBandScore)}\n'
        '${_r('techFineStripe')}: ${_diagnosticValue(liveProbeFineStripeScore)}\n'
        '${_r('techFineGrid')}: ${_diagnosticValue(liveProbeFineGridScore)}\n'
        '${_r('techMoireFrequency')}: ${_diagnosticValue(liveProbeMoireFrequencyScore)}\n'
        '${_r('techDynamicChallenge')}: ${_diagnosticValue(liveProbeDynamicChallengeScore)}\n'
        '${_r('techPersistentPattern')}: ${_diagnosticValue(liveProbePersistentPatternScore)}\n'
        '${_r('techOpticalTrace')}: ${_diagnosticValue(liveProbeOpticalCorroboratedTrace)}\n'
        '${_r('techMoireTrace')}: ${_diagnosticValue(liveProbeMoireFrequencyTrace)}\n'
        '${_r('techDynamicTrace')}: ${_diagnosticValue(liveProbeDynamicScreenChallengeTrace)}\n'
        '${_r('techUncorroborated')}: ${_diagnosticValue(liveProbeUncorroboratedDisplayPattern)}\n'
        '\n${_r('techMl')}\n'
        '${_r('techAnalysisStatus')}: ${_diagnosticValue(ml?['analysisStatus'])}\n'
        '${_r('techModelSource')}: ${_diagnosticValue(ml?['modelSource'])}\n'
        '${_r('techModelVersion')}: ${_diagnosticValue(ml?['modelVersion'])}\n'
        '${_r('techRuntime')}: ${_diagnosticValue(ml?['tfliteRuntimeVersion'])}\n'
        '${_r('techModelSha')}: ${_diagnosticValue(ml?['modelSha256'])}\n'
        '${_r('techPredictedClass')}: ${_diagnosticValue(ml?['predictedClass'])}\n'
        '${_r('techConfidence')}: ${_diagnosticValue(ml?['predictedClassConfidence'])}\n'
        '${_r('techScreenProbability')}: ${_diagnosticValue(ml?['screenProbability'])}\n'
        '${_r('techRisk')}: ${_diagnosticValue(ml?['screenReplayRisk'])}\n'
        '${_r('techScore')}: ${_diagnosticValue(ml?['screenReplayRiskScore'])}\n'
        '${_r('techMlDecision')}: ${_diagnosticValue(ml?['displayRiskDecision'])}\n'
        '${_r('techReason')}: ${_diagnosticValue(ml?['reason'])}\n'
        '${_r('techError')}: ${_diagnosticValue(ml?['error'])}';
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
                  '${_r('contentType')}: ${contentType ?? '-'}',
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
