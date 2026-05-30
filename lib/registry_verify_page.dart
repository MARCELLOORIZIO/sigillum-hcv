import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'hcv_registry_service.dart';
import 'hcv_verifier.dart';
import 'package:path/path.dart' as p;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

import 'hcv_social_fingerprint.dart';

class RegistryVerifyPage extends StatefulWidget {
  final String? initialMediaPath;

  const RegistryVerifyPage({
    super.key,
    this.initialMediaPath,
  });

  @override
  State<RegistryVerifyPage> createState() => _RegistryVerifyPageState();
}

class _RegistryVerifyPageState extends State<RegistryVerifyPage> {
  String? extractHcvIdFromName(String fileName) {
    final patterns = [
      RegExp(r'hcv_video_(HCV-[A-Z0-9]+)', caseSensitive: false),
      RegExp(r'(HCV-[A-Z0-9]+)', caseSensitive: false),
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

    final match = RegExp(r'HCV-[A-F0-9]{8}').firstMatch(normalized);
    return match?.group(0);
  }

  String normalizeSocialText(String value) {
    final footer = RegExp(
      r'\s+HCV VERIFIED\s*[^\r\n]*\s+ID:\s*HCV-[A-F0-9]{8}\s+VERIFY WITH SIGILLUM\s*$',
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
    try {
      final inputImage = InputImage.fromFilePath(path);

      final textRecognizer =
          TextRecognizer(script: TextRecognitionScript.latin);

      final recognizedText = await textRecognizer.processImage(inputImage);

      await textRecognizer.close();

      final normalized = recognizedText.text
          .toUpperCase()
          .replaceAll(' ', '')
          .replaceAll('\n', '')
          .replaceAll('\r', '')
          .replaceAll('HCV-ID:', 'HCV-')
          .replaceAll('HCVID:', 'HCV-')
          .replaceAll('HCVID', 'HCV-')
          .replaceAll('HCV1D:', 'HCV-')
          .replaceAll('HCV1D', 'HCV-')
          .replaceAll('HCV_LD', 'HCV-')
          .replaceAll('HCV_ID', 'HCV-')
          .replaceAll('HCV—', 'HCV-')
          .replaceAll('HCV—', 'HCV-')
          .replaceAll('HCV_', 'HCV-')
          .replaceAll('O', '0');

      final match = RegExp(r'HCV-[A-F0-9]{8}').firstMatch(normalized);

      if (match != null) {
        return match.group(0);
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> extractHcvIdFromVideoFrame(String videoPath) async {
    final times = [
      '00:00:00.2',
      '00:00:00.8',
      '00:00:01.5',
      '00:00:02.5',
      '00:00:04.0',
      '00:00:06.0',
      '00:00:08.0',
    ];

    for (final time in times) {
      try {
        final tempDir = await getTemporaryDirectory();
        final framePath =
            '${tempDir.path}/hcv_ocr_frame_${DateTime.now().millisecondsSinceEpoch}.jpg';

        final command = "-y -ss $time -i '$videoPath' "
            "-vf \"crop=iw:ih*0.35:0:ih*0.65,scale=iw*2:ih*2,eq=contrast=1.6:brightness=0.05:saturation=1.2\" "
            "-frames:v 1 '$framePath'";

        final session = await FFmpegKit.execute(command);
        final code = await session.getReturnCode();

        if (code != null && ReturnCode.isSuccess(code)) {
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

  List<String> _b8Variants(String hcvId) {
    final match = RegExp(r'^HCV-([A-F0-9]{8})$').firstMatch(hcvId);

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
              candidate, await registry.fetchCertificate(candidate));
        } catch (_) {}
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

      final count = storedHashes.length < currentHashes.length
          ? storedHashes.length
          : currentHashes.length;

      if (count == 0) {
        return false;
      }

      var matched = 0;

      for (var i = 0; i < count; i++) {
        final expected = storedHashes[i].toString();
        final actual = currentHashes[i].toString();
        final distance = _hexDistance(expected, actual);

        if (distance <= 72) {
          matched++;
        }
      }

      return matched >= (count / 2).ceil();
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
  String? screenReplaySegmentsAnalyzed;
  String? screenReplayWorstSecond;
  String? liveProbeFrames;
  String? liveProbeRisk;
  String? localTemporalFlickerScore;
  String? refreshBandScore;
  String? pixelGridUniformityScore;
  String? liveProbeLocalFlickerScore;
  String? liveProbeRefreshBandScore;
  String? liveProbeFineStripeScore;
  String? liveProbeFineGridScore;
  String? liveProbeMoireFrequencyScore;
  String? liveProbeOpticalCorroboratedTrace;
  String? liveProbeMoireFrequencyTrace;
  String? liveProbeUncorroboratedDisplayPattern;
  String? syntheticRisk;
  String? sceneAuthenticity;
  String? aiProofLevel;

  bool loading = false;
  bool hcvIdDetectedByOcr = false;

  @override
  void initState() {
    super.initState();

    final path = widget.initialMediaPath;

    if (path != null && path.isNotEmpty) {
      Future.microtask(() => _autoVerifySharedPath(path));
    }
  }

  Future<void> _autoVerifySharedPath(String path) async {
    if (!mounted) return;

    setState(() {
      mediaPath = path;
      result = null;
      status = 'File ricevuto. Lettura HCV-ID e verifica automatica...';
      hcvIdDetectedByOcr = false;
    });

    final detectedId = await detectHcvIdFromMediaPath(path);

    if (!mounted) return;

    if (detectedId == null || detectedId.isEmpty) {
      setState(() {
        status =
            'File ricevuto, ma HCV-ID non rilevato automaticamente. Inseriscilo e premi VERIFICA DA REGISTRY.';
      });
      return;
    }

    setState(() {
      hcvIdDetectedByOcr = true;
      idController.text = detectedId;
      status = 'HCV-ID rilevato. Verifica Registry automatica...';
    });

    await verifyFromRegistry();
  }

  @override
  void dispose() {
    idController.dispose();
    super.dispose();
  }

  Future<void> pickMedia() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      withData: true,
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
        result = 'INVALID ❌';
        status =
            'Qui devi selezionare il file ORIGINALE (mp4, jpg, pdf, txt, audio), NON .hcv o .hcvpack';
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
          status = 'HCV-ID rilevato via OCR nel media ✔';
        });
      }

      if (ocrId != null) {
        idController.text = ocrId;

        setState(() {
          status = 'HCV-ID rilevato via OCR ✔';
        });
      }
    }

    setState(() {
      mediaPath = path;
      result = null;

      status = detectedId != null
          ? 'HCV-ID rilevato dal nome file. Ora premi VERIFICA DA REGISTRY'
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
      screenReplaySegmentsAnalyzed = null;
      screenReplayWorstSecond = null;
      liveProbeFrames = null;
      liveProbeRisk = null;
      localTemporalFlickerScore = null;
      refreshBandScore = null;
      pixelGridUniformityScore = null;
      liveProbeLocalFlickerScore = null;
      liveProbeRefreshBandScore = null;
      liveProbeFineStripeScore = null;
      liveProbeFineGridScore = null;
      liveProbeMoireFrequencyScore = null;
      liveProbeOpticalCorroboratedTrace = null;
      liveProbeMoireFrequencyTrace = null;
      liveProbeUncorroboratedDisplayPattern = null;
      syntheticRisk = null;
      sceneAuthenticity = null;
      aiProofLevel = null;
    });

    try {
      final resolved = await _fetchCertificate(hcvId);
      hcvId = resolved.key;
      final cert = resolved.value;
      idController.text = hcvId;

      final claims = cert['claims'];

      if (claims is Map) {
        hcvTrustLevel = claims['trustLevel']?.toString();
        liveCaptureTrust = claims['liveCaptureTrust']?.toString();
        screenReplayRisk = claims['screenReplayRisk']?.toString();
        screenReplayRiskScore = claims['screenReplayRiskScore']?.toString();
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
          liveProbeLocalFlickerScore =
              liveScreenProbe['localTemporalFlickerScore']?.toString();
          liveProbeRefreshBandScore =
              liveScreenProbe['refreshBandScore']?.toString();
          liveProbeFineStripeScore =
              liveScreenProbe['fineStripeScore']?.toString();
          liveProbeFineGridScore =
              liveScreenProbe['fineGridScore']?.toString();
          liveProbeMoireFrequencyScore =
              liveScreenProbe['moireFrequencyScore']?.toString();
          final liveProbeSignals = liveScreenProbe['signals'];
          if (liveProbeSignals is Map) {
            liveProbeOpticalCorroboratedTrace =
                liveProbeSignals['opticalCorroboratedTrace']?.toString();
            liveProbeMoireFrequencyTrace =
                liveProbeSignals['moireFrequencyTrace']?.toString();
            liveProbeUncorroboratedDisplayPattern =
                liveProbeSignals['uncorroboratedDisplayPattern']?.toString();
          }
        }
        syntheticRisk = claims['syntheticRisk']?.toString();
        sceneAuthenticity = claims['sceneAuthenticity']?.toString();
        aiProofLevel = claims['aiProofLevel']?.toString();
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

          result = 'INVALID ❌';

          certificate = cert;
        });

        return;
      }

      final content = cert['content'];

      if (content is! Map<String, dynamic>) {
        setState(() {
          loading = false;

          status = 'Certificato senza content binding';

          result = 'INVALID ❌';

          certificate = cert;
        });

        return;
      }

      final mediaFile = File(mediaPath!);

      if (!await mediaFile.exists()) {
        setState(() {
          loading = false;

          status = 'File media non trovato';

          result = 'INVALID ❌';
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
        identityAssuranceLevel =
            identity['identityAssuranceLevel']?.toString();
        legalIdentityStatus = identity['legalIdentityStatus']?.toString();
        identityFingerprint = identity['identityFingerprint']?.toString();
        creatorKeyFingerprint =
            identity['devicePublicKeyFingerprint']?.toString();
      }

      contentType = contentTypeForVerification;

      final forensicVerified = actualHash == expectedHash;
      final videoFingerprintMatches =
          await _matchesCertifiedVideoFingerprint(cert);
      final imageFingerprintMatches =
          await _matchesCertifiedImageFingerprint(cert);

      setState(() {
        loading = false;

        certificate = cert;

        void markVerified(String cleanStatus, String cleanResult) {
          if (_isScreenReplayRisk(screenReplayRisk)) {
            status = '$cleanStatus\n\n'
                'ATTENZIONE: possibile ripresa di uno schermo rilevata '
                '($screenReplayRisk). Il media è collegato al certificato, '
                'ma la scena non va trattata come ripresa diretta della realtà.';

            result = 'VERIFIED WITH SCREEN RISK ⚠️';
          } else {
            status = cleanStatus;
            result = cleanResult;
          }
        }

        if (forensicVerified) {
          markVerified(
            'FORENSIC VERIFIED ✔\nFile identico all’originale certificato. Hash SHA-256 corrispondente.',
            'FORENSIC VERIFIED ✔',
          );
        } else if (socialTextVerified) {
          markVerified(
            'SOCIAL VERIFIED ✔\nTesto originale verificato. Il post contiene footer SIGILLUM/HCV-ID, quindi il file non è identico byte-per-byte ma il contenuto certificato corrisponde.',
            'SOCIAL VERIFIED ✔',
          );
        } else {
          status =
              'SOCIAL VERIFIED ✔\nFile ricompresso, rinominato o modificato dai social. HCV-ID e certificato Registry validi, ma hash non identico.';

          final hcvIdWasDetectedInMedia = hcvIdDetectedByOcr;

          if (hcvIdWasDetectedInMedia &&
              contentType == 'video' &&
              videoFingerprintMatches == true) {
            markVerified(
              'SOCIAL VERIFIED ✔\nHCV-ID rilevato nel video, certificato Registry valido e fingerprint video compatibile. Hash diverso perché il file è stato ricompresso o rinominato.',
              'SOCIAL VERIFIED ✔',
            );
          } else if (hcvIdWasDetectedInMedia &&
              contentType == 'video' &&
              videoFingerprintMatches == null) {
            markVerified(
              'SOCIAL VERIFIED ✔\nHCV-ID rilevato nel media e certificato Registry valido. Hash diverso perché il file è stato ricompresso o rinominato.',
              'SOCIAL VERIFIED ✔',
            );
          } else if (hcvIdWasDetectedInMedia &&
              contentType == 'video' &&
              videoFingerprintMatches == false) {
            status =
                'HCV-ID rilevato nel video, ma il fingerprint social non corrisponde al contenuto certificato. Possibile ID sovrapposto a un video diverso.';

            result = 'ID VALID / MEDIA NOT VERIFIED ⚠️';
          } else if (hcvIdWasDetectedInMedia &&
              contentType == 'photo' &&
              imageFingerprintMatches == true) {
            markVerified(
              'SOCIAL VERIFIED ✔\nHCV-ID rilevato nella foto, certificato Registry valido e fingerprint immagine compatibile. Hash diverso perché il file è stato ricompresso o rinominato.',
              'SOCIAL VERIFIED ✔',
            );
          } else if (hcvIdWasDetectedInMedia &&
              contentType == 'photo' &&
              imageFingerprintMatches == null) {
            markVerified(
              'SOCIAL VERIFIED ✔\nHCV-ID rilevato nella foto e certificato Registry valido. Foto legacy senza fingerprint immagine: verifica social meno forte.',
              'SOCIAL VERIFIED ✔',
            );
          } else if (hcvIdWasDetectedInMedia &&
              contentType == 'photo' &&
              imageFingerprintMatches == false) {
            status =
                'HCV-ID rilevato nella foto, ma il fingerprint immagine non corrisponde al contenuto certificato. Possibile ID sovrapposto a una foto diversa.';

            result = 'ID VALID / MEDIA NOT VERIFIED ⚠️';
          } else if (hcvIdWasDetectedInMedia && contentType != 'text') {
            markVerified(
              'SOCIAL VERIFIED ✔\nHCV-ID rilevato nel media e certificato Registry valido. Hash diverso perché il file è stato ricompresso o rinominato.',
              'SOCIAL VERIFIED ✔',
            );
          } else {
            status =
                'HCV-ID valido nel Registry, ma non rilevato automaticamente nel file selezionato. Verifica social non conclusiva.';

            result = 'ID VALID / MEDIA NOT VERIFIED ⚠️';
          }
        }
      });
    } catch (e) {
      setState(() {
        loading = false;

        status = 'ERRORE REGISTRY: $e';

        result = 'INVALID ❌';
      });
    }
  }

  bool get isVerified =>
      result == 'HUMAN VERIFIED ✔' ||
      result == 'FORENSIC VERIFIED ✔' ||
      result == 'SOCIAL VERIFIED ✔';

  bool get isScreenReplayWarning => result == 'VERIFIED WITH SCREEN RISK ⚠️';

  bool _isScreenReplayRisk(String? risk) {
    final value = risk?.toUpperCase();
    return value == 'MEDIUM' || value == 'HIGH';
  }

  String _shortFingerprint(String? value) {
    if (value == null || value.isEmpty) return '-';
    if (value.length <= 18) return value;
    return '${value.substring(0, 10)}...${value.substring(value.length - 8)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify by HCV-ID'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                result == null
                    ? Icons.cloud_sync
                    : isVerified
                        ? Icons.verified
                        : isScreenReplayWarning
                            ? Icons.warning_amber
                            : Icons.error,
                size: 72,
                color: result == null
                    ? Colors.grey
                    : isVerified
                        ? Colors.green
                        : isScreenReplayWarning
                            ? Colors.orange
                            : Colors.red,
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
              ElevatedButton(
                onPressed: loading ? null : pickMedia,
                child: const Text('SELEZIONA MEDIA ORIGINALE'),
              ),
              if (mediaPath != null) ...[
                const SizedBox(height: 8),
                Text(
                  mediaPath!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11),
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: loading ? null : verifyFromRegistry,
                child: Text(
                  loading ? 'VERIFICA...' : 'VERIFICA DA REGISTRY',
                ),
              ),
              const SizedBox(height: 20),
              Text(
                status,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Il certificato viene recuperato automaticamente dal Registry HCV. Devi selezionare SOLO il file originale.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              if (result != null) ...[
                const SizedBox(height: 20),
                Text(
                  result!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isVerified
                        ? Colors.green
                        : isScreenReplayWarning
                            ? Colors.orange
                            : Colors.red,
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
                  'Creator: ${creatorName ?? '-'}\n'
                  'Trust: ${trustLevel ?? '-'}\n'
                  'Identity: ${identityAssuranceLevel ?? '-'}\n'
                  'Legal Identity: ${legalIdentityStatus ?? '-'}\n'
                  'Identity Fingerprint: ${_shortFingerprint(identityFingerprint)}\n'
                  'Creator Key: ${_shortFingerprint(creatorKeyFingerprint)}\n'
                  'Type: ${contentType ?? '-'}',
                  textAlign: TextAlign.center,
                ),
              ],
              if (hcvTrustLevel != null ||
                  liveCaptureTrust != null ||
                  screenReplayRisk != null ||
                  screenReplaySegmentsAnalyzed != null ||
                  screenReplayWorstSecond != null ||
                  liveProbeFrames != null ||
                  liveProbeRisk != null ||
                  localTemporalFlickerScore != null ||
                  refreshBandScore != null ||
                  pixelGridUniformityScore != null ||
                  liveProbeLocalFlickerScore != null ||
                  liveProbeRefreshBandScore != null ||
                  liveProbeFineStripeScore != null ||
                  liveProbeFineGridScore != null ||
                  liveProbeMoireFrequencyScore != null ||
                  liveProbeOpticalCorroboratedTrace != null ||
                  liveProbeMoireFrequencyTrace != null ||
                  liveProbeUncorroboratedDisplayPattern != null ||
                  syntheticRisk != null ||
                  sceneAuthenticity != null ||
                  aiProofLevel != null) ...[
                const SizedBox(height: 16),
                const Text(
                  'HCV Trust',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Trust Level: ${hcvTrustLevel ?? '-'}\n'
                  'Live Capture: ${liveCaptureTrust ?? '-'}\n'
                  '\n'
                  'RISULTATO COMBINATO\n'
                  'Rischio schermo: ${screenReplayRisk ?? '-'}\n'
                  'Punteggio schermo: ${screenReplayRiskScore ?? '-'}\n'
                  '\n'
                  'LIVE PROBE PRIMA DELLO SCATTO\n'
                  'Live Probe Risk: ${liveProbeRisk ?? '-'}\n'
                  'Live Probe Frames: ${liveProbeFrames ?? '-'}\n'
                  'Live Probe Local Flicker: ${liveProbeLocalFlickerScore ?? '-'}\n'
                  'Live Probe Refresh Band: ${liveProbeRefreshBandScore ?? '-'}\n'
                  'Live Probe Fine Stripe: ${liveProbeFineStripeScore ?? '-'}\n'
                  'Live Probe Fine Grid: ${liveProbeFineGridScore ?? '-'}\n'
                  'Live Probe Moire Frequency: ${liveProbeMoireFrequencyScore ?? '-'}\n'
                  'Live Probe Optical Confirmed: ${liveProbeOpticalCorroboratedTrace ?? '-'}\n'
                  'Live Probe Moire Trace: ${liveProbeMoireFrequencyTrace ?? '-'}\n'
                  'Live Probe Unconfirmed Pattern: ${liveProbeUncorroboratedDisplayPattern ?? '-'}\n'
                  '\n'
                  'ANALISI FILE DOPO LO SCATTO\n'
                  'Replay Segments: ${screenReplaySegmentsAnalyzed ?? '-'}\n'
                  'Worst Replay Second: ${screenReplayWorstSecond ?? '-'}\n'
                  'Local Flicker Score: ${localTemporalFlickerScore ?? '-'}\n'
                  'Refresh Band Score: ${refreshBandScore ?? '-'}\n'
                  'Pixel Grid Uniformity: ${pixelGridUniformityScore ?? '-'}\n'
                  '\n'
                  'Synthetic Risk: ${syntheticRisk ?? '-'}\n'
                  'Scene Authenticity: ${sceneAuthenticity ?? '-'}\n'
                  'AI Proof Level: ${aiProofLevel ?? '-'}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
