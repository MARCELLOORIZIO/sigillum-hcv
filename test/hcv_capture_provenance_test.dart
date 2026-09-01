import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_capture_provenance.dart';
import 'package:sigillum_iphone/hcv_provenance_chain.dart';

const Map<String, dynamic> _testPublicKey = {
  'modulus': 'LOCAL_DEV_PUBLIC_KEY',
  'exponent': 'LOCAL_DEV',
};

Future<HCVProvenanceSignature> _testSigner(String data) async {
  return HCVProvenanceSignature(
    signature:
        sha256.convert(utf8.encode('LOCAL_DEV_SIGNATURE:$data')).toString(),
    publicKey: _testPublicKey,
  );
}

void main() {
  test('D2 binds finalized photo hash to HCV session and device key', () async {
    final dir = await Directory.systemTemp.createTemp('hcv_capture_binding_');
    addTearDown(() => dir.delete(recursive: true));

    final deviceFingerprint =
        HCVProvenanceChain.publicKeyFingerprint(_testPublicKey);
    final binder = HCVCaptureProvenance(
      identityLoader: () async => {
        'devicePublicKeyFingerprint': deviceFingerprint,
      },
      chainFactory: (file) => HCVProvenanceChain(
        logFile: file,
        signer: _testSigner,
        now: () => DateTime.utc(2026, 9, 1, 15),
        nonceGenerator: () => 'capture-nonce-1',
      ),
    );

    final contentHash = sha256.convert(utf8.encode('photo-bytes')).toString();
    final binding = await binder.bindFinalizedCapture(
      outputDirectory: dir,
      hcvId: 'HCV-ABCDEF0123456789',
      sessionId: 'engine-session-123',
      mediaType: 'photo',
      contentHash: contentHash,
      contentSize: 1234,
      contentName: 'hcv_photo_HCV-ABCDEF0123456789.jpg',
      capturedAt: DateTime.utc(2026, 9, 1, 14, 59, 59),
    );

    expect(await File(binding.logPath).exists(), isTrue);
    expect(binding.event['eventType'], 'CAPTURE_FINALIZED');
    expect(binding.event['inputHash'], contentHash);
    expect(binding.event['deviceFingerprint'], deviceFingerprint);
    expect(binding.event['sessionId'], 'engine-session-123');
    expect(binding.event['pipelineVersion'], 'HCV_CAPTURE_BINDING_V1');

    final claim = binding.toClaim(hcvId: 'HCV-ABCDEF0123456789');
    expect(claim['type'], 'SIGILLUM_CAPTURE_PROVENANCE_BINDING');
    expect(claim['status'], 'VERIFIED');
    expect(claim['eventHash'], binding.event['eventHash']);
    expect(claim['inputHash'], contentHash);
    expect(claim['event'], binding.event);
  });

  test('D2 uses a separate provenance log for each HCV-ID', () async {
    final dir = await Directory.systemTemp.createTemp('hcv_capture_logs_');
    addTearDown(() => dir.delete(recursive: true));

    final fingerprint = HCVProvenanceChain.publicKeyFingerprint(_testPublicKey);
    var nonce = 0;
    final binder = HCVCaptureProvenance(
      identityLoader: () async => {
        'devicePublicKeyFingerprint': fingerprint,
      },
      chainFactory: (file) => HCVProvenanceChain(
        logFile: file,
        signer: _testSigner,
        nonceGenerator: () => 'nonce-${nonce++}',
      ),
    );

    final hashA = sha256.convert(utf8.encode('A')).toString();
    final hashB = sha256.convert(utf8.encode('B')).toString();

    final first = await binder.bindFinalizedCapture(
      outputDirectory: dir,
      hcvId: 'HCV-AAAAAAAAAAAAAAAA',
      sessionId: 'session-a',
      mediaType: 'photo',
      contentHash: hashA,
      contentSize: 1,
      contentName: 'a.jpg',
      capturedAt: DateTime.utc(2026, 9, 1),
    );
    final second = await binder.bindFinalizedCapture(
      outputDirectory: dir,
      hcvId: 'HCV-BBBBBBBBBBBBBBBB',
      sessionId: 'session-b',
      mediaType: 'video',
      contentHash: hashB,
      contentSize: 2,
      contentName: 'b.mp4',
      capturedAt: DateTime.utc(2026, 9, 1, 0, 0, 1),
    );

    expect(first.logPath, isNot(second.logPath));
    expect(await File(first.logPath).exists(), isTrue);
    expect(await File(second.logPath).exists(), isTrue);
  });

  test('D2 refuses to overwrite an existing HCV provenance log', () async {
    final dir = await Directory.systemTemp.createTemp('hcv_capture_duplicate_');
    addTearDown(() => dir.delete(recursive: true));

    final fingerprint = HCVProvenanceChain.publicKeyFingerprint(_testPublicKey);
    var nonce = 0;
    final binder = HCVCaptureProvenance(
      identityLoader: () async => {
        'devicePublicKeyFingerprint': fingerprint,
      },
      chainFactory: (file) => HCVProvenanceChain(
        logFile: file,
        signer: _testSigner,
        nonceGenerator: () => 'nonce-${nonce++}',
      ),
    );

    final hash = sha256.convert(utf8.encode('same-content')).toString();
    Future<void> bind() async {
      await binder.bindFinalizedCapture(
        outputDirectory: dir,
        hcvId: 'HCV-CCCCCCCCCCCCCCCC',
        sessionId: 'session-c',
        mediaType: 'photo',
        contentHash: hash,
        contentSize: 10,
        contentName: 'c.jpg',
        capturedAt: DateTime.utc(2026, 9, 1),
      );
    }

    await bind();
    await expectLater(bind(), throwsA(isA<StateError>()));
  });

  test('D2 rejects identity fingerprint not bound to signing key', () async {
    final dir = await Directory.systemTemp.createTemp('hcv_capture_bad_key_');
    addTearDown(() => dir.delete(recursive: true));

    final binder = HCVCaptureProvenance(
      identityLoader: () async => {
        'devicePublicKeyFingerprint': List<String>.filled(64, 'a').join(),
      },
      chainFactory: (file) => HCVProvenanceChain(
        logFile: file,
        signer: _testSigner,
        nonceGenerator: () => 'nonce-bad-key',
      ),
    );

    await expectLater(
      binder.bindFinalizedCapture(
        outputDirectory: dir,
        hcvId: 'HCV-DDDDDDDDDDDDDDDD',
        sessionId: 'session-d',
        mediaType: 'photo',
        contentHash: sha256.convert(utf8.encode('x')).toString(),
        contentSize: 1,
        contentName: 'd.jpg',
        capturedAt: DateTime.utc(2026, 9, 1),
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('D2 rejects unsupported media type before writing a log', () async {
    final dir = await Directory.systemTemp.createTemp('hcv_capture_type_');
    addTearDown(() => dir.delete(recursive: true));

    final binder = HCVCaptureProvenance(
      identityLoader: () async => const <String, dynamic>{},
      chainFactory: (file) => HCVProvenanceChain(logFile: file),
    );

    await expectLater(
      binder.bindFinalizedCapture(
        outputDirectory: dir,
        hcvId: 'HCV-EEEEEEEEEEEEEEEE',
        sessionId: 'session-e',
        mediaType: 'text',
        contentHash: sha256.convert(utf8.encode('x')).toString(),
        contentSize: 1,
        contentName: 'e.txt',
        capturedAt: DateTime.utc(2026, 9, 1),
      ),
      throwsA(isA<ArgumentError>()),
    );

    expect(await dir.list().toList(), isEmpty);
  });
}
