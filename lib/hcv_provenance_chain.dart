import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

import 'hcv_keystore_signer.dart';

class HCVProvenanceSignature {
  const HCVProvenanceSignature({
    required this.signature,
    required this.publicKey,
  });

  final String signature;
  final Map<String, dynamic> publicKey;
}

typedef HCVProvenanceSigner = Future<HCVProvenanceSignature> Function(
  String data,
);

class HCVProvenanceVerificationResult {
  const HCVProvenanceVerificationResult({
    required this.valid,
    required this.code,
    required this.message,
    required this.events,
  });

  final bool valid;
  final String code;
  final String message;
  final List<Map<String, dynamic>> events;
}

/// Append-only signed provenance log.
///
/// D1 is deliberately isolated from capture/export. Nothing in the current
/// PHOTO/VIDEO pipeline depends on this class until Capture Binding (D2).
class HCVProvenanceChain {
  HCVProvenanceChain({
    required this.logFile,
    HCVProvenanceSigner? signer,
    DateTime Function()? now,
    String Function()? nonceGenerator,
  })  : _signer = signer ?? _defaultSigner,
        _now = now ?? DateTime.now,
        _nonceGenerator = nonceGenerator ?? _randomNonce;

  static const eventSchema = 'SIGILLUM_PROVENANCE_EVENT';
  static const eventVersion = 1;
  static const signatureAlgorithm = 'RSA-SHA256-HCV-PROVENANCE-V1';
  static final RegExp _sha256Pattern = RegExp(r'^[a-f0-9]{64}$');

  final File logFile;
  final HCVProvenanceSigner _signer;
  final DateTime Function() _now;
  final String Function() _nonceGenerator;

  static Future<void> _appendTail = Future<void>.value();

  Future<Map<String, dynamic>> appendEvent({
    required String eventType,
    required String inputHash,
    required String deviceFingerprint,
    required String sessionId,
    required String pipelineVersion,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) {
    return _withAppendLock(() async {
      final cleanEventType = eventType.trim();
      final cleanInputHash = inputHash.trim().toLowerCase();
      final cleanDeviceFingerprint = deviceFingerprint.trim().toLowerCase();
      final cleanSessionId = sessionId.trim();
      final cleanPipelineVersion = pipelineVersion.trim();

      if (cleanEventType.isEmpty) {
        throw ArgumentError.value(eventType, 'eventType', 'Must not be empty');
      }
      if (!_sha256Pattern.hasMatch(cleanInputHash)) {
        throw ArgumentError.value(
          inputHash,
          'inputHash',
          'Expected lowercase SHA-256 hex',
        );
      }
      if (!_sha256Pattern.hasMatch(cleanDeviceFingerprint)) {
        throw ArgumentError.value(
          deviceFingerprint,
          'deviceFingerprint',
          'Expected lowercase SHA-256 hex',
        );
      }
      if (cleanSessionId.isEmpty) {
        throw ArgumentError.value(sessionId, 'sessionId', 'Must not be empty');
      }
      if (cleanPipelineVersion.isEmpty) {
        throw ArgumentError.value(
          pipelineVersion,
          'pipelineVersion',
          'Must not be empty',
        );
      }

      final existing = await verify();
      if (!existing.valid && existing.code != 'EMPTY') {
        throw StateError(
          'Cannot append to an invalid provenance log: ${existing.code}',
        );
      }

      final sequence = existing.events.length;
      final parentEvent = sequence == 0
          ? 'GENESIS'
          : existing.events.last['eventHash']?.toString();
      if (parentEvent == null || parentEvent.isEmpty) {
        throw StateError('Previous provenance event has no eventHash');
      }

      final body = <String, dynamic>{
        'type': eventSchema,
        'version': eventVersion,
        'sequence': sequence,
        'eventType': cleanEventType,
        'inputHash': cleanInputHash,
        'timestamp': _now().toUtc().toIso8601String(),
        'deviceFingerprint': cleanDeviceFingerprint,
        'sessionId': cleanSessionId,
        'pipelineVersion': cleanPipelineVersion,
        'nonce': _nonceGenerator(),
        'parentEvent': parentEvent,
        'metadata': _normalizeJson(metadata),
      };

      final eventHash = _sha256(canonicalJson(body));
      final signed = await _signer(eventHash);
      if (signed.signature.trim().isEmpty) {
        throw StateError('Empty provenance signature');
      }

      final event = <String, dynamic>{
        ...body,
        'eventHash': eventHash,
        'signatureAlgorithm': signatureAlgorithm,
        'signature': signed.signature,
        'publicKey': _normalizeJson(signed.publicKey),
      };

      if (!await logFile.parent.exists()) {
        await logFile.parent.create(recursive: true);
      }
      await logFile.writeAsString(
        '${canonicalJson(event)}\n',
        mode: FileMode.append,
        flush: true,
      );

      return event;
    });
  }

  Future<HCVProvenanceVerificationResult> verify() async {
    if (!await logFile.exists()) {
      return const HCVProvenanceVerificationResult(
        valid: false,
        code: 'EMPTY',
        message: 'No provenance events.',
        events: <Map<String, dynamic>>[],
      );
    }

    final raw = await logFile.readAsString();
    final lines = raw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) {
      return const HCVProvenanceVerificationResult(
        valid: false,
        code: 'EMPTY',
        message: 'No provenance events.',
        events: <Map<String, dynamic>>[],
      );
    }

    final events = <Map<String, dynamic>>[];
    final seenNonces = <String>{};
    DateTime? previousTimestamp;

    for (var index = 0; index < lines.length; index++) {
      dynamic decoded;
      try {
        decoded = jsonDecode(lines[index]);
      } catch (_) {
        return _invalid('MALFORMED', 'Event $index is not valid JSON.', events);
      }
      if (decoded is! Map<String, dynamic>) {
        return _invalid('MALFORMED', 'Event $index is not a JSON object.', events);
      }
      final event = Map<String, dynamic>.from(decoded);

      if (event['type'] != eventSchema || event['version'] != eventVersion) {
        return _invalid('SCHEMA', 'Event $index has an unsupported schema.', events);
      }
      if (event['sequence'] != index) {
        return _invalid('ORDER', 'Event sequence is not append order.', events);
      }

      final inputHash = event['inputHash']?.toString().toLowerCase() ?? '';
      final deviceFingerprint =
          event['deviceFingerprint']?.toString().toLowerCase() ?? '';
      if (!_sha256Pattern.hasMatch(inputHash) ||
          !_sha256Pattern.hasMatch(deviceFingerprint)) {
        return _invalid('SCHEMA', 'Event $index contains invalid hashes.', events);
      }

      final nonce = event['nonce']?.toString() ?? '';
      if (nonce.isEmpty || !seenNonces.add(nonce)) {
        return _invalid('REPLAY', 'Duplicate or empty nonce at event $index.', events);
      }

      final timestampRaw = event['timestamp']?.toString() ?? '';
      final timestamp = DateTime.tryParse(timestampRaw)?.toUtc();
      if (timestamp == null) {
        return _invalid('SCHEMA', 'Invalid timestamp at event $index.', events);
      }
      if (previousTimestamp != null && timestamp.isBefore(previousTimestamp)) {
        return _invalid('ORDER', 'Event timestamps are out of order.', events);
      }
      previousTimestamp = timestamp;

      final expectedParent = index == 0
          ? 'GENESIS'
          : events[index - 1]['eventHash']?.toString();
      if (event['parentEvent'] != expectedParent) {
        return _invalid('CHAIN', 'Broken parent link at event $index.', events);
      }

      final storedHash = event['eventHash']?.toString() ?? '';
      if (!_sha256Pattern.hasMatch(storedHash)) {
        return _invalid('HASH', 'Invalid event hash at event $index.', events);
      }

      final unsignedBody = Map<String, dynamic>.from(event)
        ..remove('eventHash')
        ..remove('signatureAlgorithm')
        ..remove('signature')
        ..remove('publicKey');
      final recalculatedHash = _sha256(canonicalJson(unsignedBody));
      if (storedHash != recalculatedHash) {
        return _invalid('TAMPER', 'Event $index payload was modified.', events);
      }

      if (event['signatureAlgorithm'] != signatureAlgorithm) {
        return _invalid(
          'SIGNATURE',
          'Unsupported signature algorithm at event $index.',
          events,
        );
      }
      final signature = event['signature'];
      final publicKey = event['publicKey'];
      if (signature is! String || publicKey is! Map) {
        return _invalid('SIGNATURE', 'Missing signature at event $index.', events);
      }
      if (!_verifySignature(
        data: storedHash,
        signature: signature,
        publicKey: Map<String, dynamic>.from(publicKey),
      )) {
        return _invalid('SIGNATURE', 'Invalid signature at event $index.', events);
      }

      events.add(event);
    }

    return HCVProvenanceVerificationResult(
      valid: true,
      code: 'VERIFIED',
      message: 'Provenance chain verified.',
      events: List<Map<String, dynamic>>.unmodifiable(events),
    );
  }

  Future<T> _withAppendLock<T>(Future<T> Function() action) {
    final previous = _appendTail;
    final release = Completer<void>();
    _appendTail = release.future;
    return () async {
      await previous;
      try {
        return await action();
      } finally {
        if (!release.isCompleted) release.complete();
      }
    }();
  }

  static Future<HCVProvenanceSignature> _defaultSigner(String data) async {
    final signature = await HCVKeystoreSigner.sign(data);
    final publicKey = await HCVKeystoreSigner.getPublicKey();
    return HCVProvenanceSignature(
      signature: signature,
      publicKey: publicKey,
    );
  }

  static HCVProvenanceVerificationResult _invalid(
    String code,
    String message,
    List<Map<String, dynamic>> events,
  ) {
    return HCVProvenanceVerificationResult(
      valid: false,
      code: code,
      message: message,
      events: List<Map<String, dynamic>>.unmodifiable(events),
    );
  }

  static String canonicalJson(Object? value) {
    return jsonEncode(_normalizeJson(value));
  }

  static Object? _normalizeJson(Object? value) {
    if (value == null || value is String || value is bool || value is num) {
      return value;
    }
    if (value is List) {
      return value.map<Object?>((item) => _normalizeJson(item)).toList();
    }
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      return <String, dynamic>{
        for (final key in keys) key: _normalizeJson(value[key]),
      };
    }
    throw ArgumentError('Unsupported canonical JSON value: ${value.runtimeType}');
  }

  static String _sha256(String value) {
    return sha256.convert(utf8.encode(value)).toString();
  }

  static String _randomNonce() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  static bool _verifySignature({
    required String data,
    required String signature,
    required Map<String, dynamic> publicKey,
  }) {
    try {
      if (publicKey['modulus'] == 'LOCAL_DEV_PUBLIC_KEY' &&
          publicKey['exponent'] == 'LOCAL_DEV') {
        final expected = sha256
            .convert(utf8.encode('LOCAL_DEV_SIGNATURE:$data'))
            .toString();
        return signature == expected;
      }

      final modulus = publicKey['modulus'];
      final exponent = publicKey['exponent'];
      if (modulus is! String || exponent is! String) return false;

      final rsaKey = RSAPublicKey(
        _bytesToBigInt(base64Decode(modulus)),
        _bytesToBigInt(base64Decode(exponent)),
      );
      final verifier = RSASigner(SHA256Digest(), '0609608648016503040201');
      verifier.init(false, PublicKeyParameter<RSAPublicKey>(rsaKey));
      return verifier.verifySignature(
        Uint8List.fromList(utf8.encode(data)),
        RSASignature(base64Decode(signature)),
      );
    } catch (_) {
      return false;
    }
  }

  static BigInt _bytesToBigInt(List<int> bytes) {
    final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    if (hex.isEmpty) throw ArgumentError('Empty RSA integer');
    return BigInt.parse(hex, radix: 16);
  }
}
