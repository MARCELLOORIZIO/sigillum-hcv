import 'dart:io';

import 'package:path/path.dart' as p;

import 'hcv_identity.dart';
import 'hcv_provenance_chain.dart';

typedef HCVIdentityLoader = Future<Map<String, dynamic>> Function();
typedef HCVProvenanceChainFactory = HCVProvenanceChain Function(File logFile);

class HCVCaptureProvenanceBinding {
  const HCVCaptureProvenanceBinding({
    required this.event,
    required this.logPath,
  });

  final Map<String, dynamic> event;
  final String logPath;

  Map<String, dynamic> toClaim({required String hcvId}) {
    return <String, dynamic>{
      'type': HCVCaptureProvenance.bindingSchema,
      'version': 1,
      'status': 'VERIFIED',
      'hcvId': hcvId,
      'eventHash': event['eventHash'],
      'inputHash': event['inputHash'],
      'deviceFingerprint': event['deviceFingerprint'],
      'sessionId': event['sessionId'],
      'pipelineVersion': event['pipelineVersion'],
      'signatureAlgorithm': event['signatureAlgorithm'],
      'logFileName': p.basename(logPath),
      'event': event,
    };
  }
}

/// D2 bridge between the finalized camera media and the D1 provenance chain.
///
/// The binding uses the existing HCV engine session/HCV-ID and the same device
/// public-key fingerprint already exposed by HCVIdentity. It does not create a
/// second identity or signing key.
class HCVCaptureProvenance {
  HCVCaptureProvenance({
    HCVIdentityLoader? identityLoader,
    HCVProvenanceChainFactory? chainFactory,
  })  : _identityLoader = identityLoader ?? _loadIdentity,
        _chainFactory = chainFactory ?? _defaultChainFactory;

  static const bindingSchema = 'SIGILLUM_CAPTURE_PROVENANCE_BINDING';
  static const pipelineVersion = 'HCV_CAPTURE_BINDING_V1';

  final HCVIdentityLoader _identityLoader;
  final HCVProvenanceChainFactory _chainFactory;

  Future<HCVCaptureProvenanceBinding> bindFinalizedCapture({
    required Directory outputDirectory,
    required String hcvId,
    required String sessionId,
    required String mediaType,
    required String contentHash,
    required int contentSize,
    required String contentName,
    required DateTime capturedAt,
  }) async {
    final cleanHcvId = hcvId.trim();
    final cleanSessionId = sessionId.trim();
    final cleanMediaType = mediaType.trim().toLowerCase();
    final cleanContentName = contentName.trim();

    if (cleanHcvId.isEmpty) {
      throw ArgumentError.value(hcvId, 'hcvId', 'Must not be empty');
    }
    if (cleanSessionId.isEmpty) {
      throw ArgumentError.value(sessionId, 'sessionId', 'Must not be empty');
    }
    if (cleanMediaType != 'photo' && cleanMediaType != 'video') {
      throw ArgumentError.value(
        mediaType,
        'mediaType',
        'Only photo or video capture can be bound',
      );
    }
    if (cleanContentName.isEmpty) {
      throw ArgumentError.value(
        contentName,
        'contentName',
        'Must not be empty',
      );
    }
    if (contentSize <= 0) {
      throw ArgumentError.value(contentSize, 'contentSize', 'Must be positive');
    }

    final identity = await _identityLoader();
    final deviceFingerprint = identity['devicePublicKeyFingerprint']
            ?.toString()
            .trim()
            .toLowerCase() ??
        '';

    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(deviceFingerprint)) {
      throw StateError('HCV device public-key fingerprint is unavailable');
    }

    if (!await outputDirectory.exists()) {
      await outputDirectory.create(recursive: true);
    }

    final safeHcvId = cleanHcvId.replaceAll(RegExp(r'[^A-Za-z0-9\-]'), '');
    if (safeHcvId.isEmpty) {
      throw StateError('HCV-ID cannot be used for provenance log naming');
    }

    final logFile = File(
      p.join(outputDirectory.path, 'hcv_provenance_$safeHcvId.jsonl'),
    );
    if (await logFile.exists()) {
      throw StateError('Capture provenance log already exists for $cleanHcvId');
    }

    final chain = _chainFactory(logFile);
    final event = await chain.appendEvent(
      eventType: 'CAPTURE_FINALIZED',
      inputHash: contentHash,
      deviceFingerprint: deviceFingerprint,
      sessionId: cleanSessionId,
      pipelineVersion: pipelineVersion,
      metadata: <String, dynamic>{
        'hcvId': cleanHcvId,
        'mediaType': cleanMediaType,
        'contentSize': contentSize,
        'contentName': cleanContentName,
        'capturedAt': capturedAt.toUtc().toIso8601String(),
        'captureSource': 'HCV_CAMERA',
      },
    );

    final verified = await chain.verify();
    if (!verified.valid ||
        verified.events.length != 1 ||
        verified.events.single['eventHash'] != event['eventHash']) {
      throw StateError(
        'Capture provenance verification failed: ${verified.code}',
      );
    }

    return HCVCaptureProvenanceBinding(
      event: event,
      logPath: logFile.path,
    );
  }

  static Future<Map<String, dynamic>> _loadIdentity() {
    return HCVIdentity().loadIdentity();
  }

  static HCVProvenanceChain _defaultChainFactory(File logFile) {
    return HCVProvenanceChain(logFile: logFile);
  }
}
