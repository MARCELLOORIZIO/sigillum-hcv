import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_verifier.dart';

const Map<String, dynamic> _publicKey = {
  'modulus': 'LOCAL_DEV_PUBLIC_KEY',
  'exponent': 'LOCAL_DEV',
};

String _shaBytes(List<int> bytes) => sha256.convert(bytes).toString();
String _shaText(String value) => _shaBytes(utf8.encode(value));
String _sign(String value) => _shaText('LOCAL_DEV_SIGNATURE:$value');

Map<String, dynamic> _chainEvent(
  String type,
  String timestamp,
  String prev,
) {
  final event = <String, dynamic>{
    'type': type,
    'timestamp': timestamp,
    'prev': prev,
  };
  event['hash'] = _shaText(jsonEncode(event));
  return event;
}

Map<String, dynamic> _buildCertificate(List<int> mediaBytes) {
  const hcvId = 'HCV-0123456789ABCDEF';
  const sessionId = 'session-hcvpack-release-gate';
  const createdAt = '2026-09-14T07:00:00.000Z';

  final start = _chainEvent('START', '2026-09-14T06:59:58.000Z', 'GENESIS');
  final bound = _chainEvent(
    'CONTENT_BOUND',
    '2026-09-14T07:00:01.000Z',
    start['hash'] as String,
  );
  final stop = _chainEvent(
    'STOP',
    '2026-09-14T07:00:02.000Z',
    bound['hash'] as String,
  );
  final chain = <Map<String, dynamic>>[start, bound, stop];
  final rootHash = _shaText(jsonEncode(chain));

  final deviceFingerprint = _shaText(jsonEncode(_publicKey));
  const creatorId = 'creator-hcvpack-release-gate';
  const creatorName = 'HCVPACK Release Gate';
  final identityFingerprint =
      _shaText('$creatorId|$creatorName|$deviceFingerprint');

  final signedPayload = <String, dynamic>{
    'format': 'HCV_CERTIFICATE',
    'version': 2,
    'sessionId': sessionId,
    'createdAt': createdAt,
    'meta': <String, dynamic>{
      'hcvId': hcvId,
      'identity': <String, dynamic>{
        'creatorId': creatorId,
        'creatorName': creatorName,
        'devicePublicKeyFingerprint': deviceFingerprint,
        'identityFingerprint': identityFingerprint,
      },
    },
    'content': <String, dynamic>{
      'type': 'video',
      'hash': _shaBytes(mediaBytes),
      'size': mediaBytes.length,
      'name': 'video.mp4',
    },
    'claims': <String, dynamic>{
      'captureSource': 'HCV_CAMERA',
      'captureCreatedAt': createdAt,
    },
    'rootHash': rootHash,
    'chain': chain,
  };

  return <String, dynamic>{
    ...signedPayload,
    'signatureAlgorithm': 'RSA-SHA256-HCV-V2',
    'signature': _sign(jsonEncode(signedPayload)),
    'publicKey': _publicKey,
  };
}

List<int> _buildV2Pack({
  required List<int> mediaBytes,
  required Map<String, dynamic> certificate,
  bool includeMedia = true,
  bool includeCertificate = true,
  bool includeMeta = true,
  List<int>? metaMediaBytes,
  Map<String, dynamic>? metaCertificate,
}) {
  final certificateBytes = utf8.encode(jsonEncode(certificate));
  final mediaForMeta = metaMediaBytes ?? mediaBytes;
  final certificateForMeta =
      utf8.encode(jsonEncode(metaCertificate ?? certificate));
  const createdAt = '2026-09-14T07:00:03.000Z';
  final mediaSha = _shaBytes(mediaForMeta);
  final certificateSha = _shaBytes(certificateForMeta);
  final packageId = _shaText('$mediaSha|$certificateSha|$createdAt');

  final meta = <String, dynamic>{
    'type': 'HCV_PACKAGE',
    'version': 2,
    'packageId': packageId,
    'createdAt': createdAt,
    'videoFile': 'video.mp4',
    'certificateFile': 'certificate.hcv',
    'originalVideoName': 'video.mp4',
    'originalCertificateName': 'certificate.hcv',
    'videoSha256': mediaSha,
    'certificateSha256': certificateSha,
    'hashAlgorithm': 'SHA256',
    'certificateFormat': 'HCV',
  };

  final archive = Archive();
  if (includeMedia) {
    archive.addFile(ArchiveFile('video.mp4', mediaBytes.length, mediaBytes));
  }
  if (includeCertificate) {
    archive.addFile(
      ArchiveFile(
        'certificate.hcv',
        certificateBytes.length,
        certificateBytes,
      ),
    );
  }
  if (includeMeta) {
    final metaBytes = utf8.encode(jsonEncode(meta));
    archive.addFile(ArchiveFile('meta.json', metaBytes.length, metaBytes));
  }
  return ZipEncoder().encode(archive)!;
}

bool _validateV2Meta({
  required Map<String, dynamic> meta,
  required String contentSha256,
  required String certificateSha256,
}) {
  if (meta['type'] != 'HCV_PACKAGE') return false;
  if ((meta['version'] as num?)?.toInt() != 2) return false;
  if (meta['certificateFile'] != 'certificate.hcv') return false;
  if (meta['videoFile'] != 'video.mp4') return false;
  if (meta['hashAlgorithm'] != 'SHA256') return false;
  if (meta['certificateFormat'] != 'HCV') return false;
  if (meta['certificateSha256'] != certificateSha256) return false;
  if (meta['videoSha256'] != contentSha256) return false;

  final packageId = meta['packageId'];
  final createdAt = meta['createdAt'];
  if (packageId is! String || packageId.isEmpty) return false;
  if (createdAt is! String || createdAt.isEmpty) return false;
  return packageId == _shaText('$contentSha256|$certificateSha256|$createdAt');
}

Future<String> _verifyContentBinding({
  required List<int> contentBytes,
  required Map<String, dynamic> certificate,
  required Directory tempDir,
}) async {
  final certFile = File('${tempDir.path}/certificate.hcv');
  await certFile.writeAsString(jsonEncode(certificate), flush: true);

  final certOk = await HCVVerifier().verifyFile(certFile.path);
  if (!certOk) return 'INVALID';

  final content = certificate['content'];
  if (content is! Map<String, dynamic>) return 'INVALID';
  final storedHash = content['hash'];
  if (storedHash is! String) return 'INVALID';

  return _shaBytes(contentBytes) == storedHash ? 'HUMAN VERIFIED' : 'TAMPERED';
}

Future<String> _verifyOfflinePack(List<int> packBytes, Directory tempDir) async {
  try {
    final isZip = packBytes.length >= 4 &&
        packBytes[0] == 0x50 &&
        packBytes[1] == 0x4b &&
        packBytes[2] == 0x03 &&
        packBytes[3] == 0x04;

    if (!isZip) {
      final data = jsonDecode(utf8.decode(packBytes));
      if (data is! Map<String, dynamic>) return 'ERROR';
      final encodedVideo = data['video'];
      final certificate = data['certificate'];
      if (encodedVideo is! String || certificate is! Map<String, dynamic>) {
        return 'ERROR';
      }
      return _verifyContentBinding(
        contentBytes: base64Decode(encodedVideo),
        certificate: certificate,
        tempDir: tempDir,
      );
    }

    final archive = ZipDecoder().decodeBytes(packBytes);
    ArchiveFile? certEntry;
    ArchiveFile? metaEntry;
    ArchiveFile? videoEntry;
    for (final entry in archive.files) {
      if (entry.name == 'certificate.hcv') certEntry = entry;
      if (entry.name == 'meta.json') metaEntry = entry;
      if (entry.name == 'video.mp4') videoEntry = entry;
    }
    if (certEntry == null || metaEntry == null || videoEntry == null) {
      return 'ERROR';
    }

    final certBytes = List<int>.from(certEntry.content as List<int>);
    final metaBytes = List<int>.from(metaEntry.content as List<int>);
    final videoBytes = List<int>.from(videoEntry.content as List<int>);
    final meta = jsonDecode(utf8.decode(metaBytes));
    if (meta is! Map<String, dynamic>) return 'ERROR';

    if (!_validateV2Meta(
      meta: meta,
      contentSha256: _shaBytes(videoBytes),
      certificateSha256: _shaBytes(certBytes),
    )) {
      return 'TAMPERED';
    }

    final certificate = jsonDecode(utf8.decode(certBytes));
    if (certificate is! Map<String, dynamic>) return 'ERROR';
    return _verifyContentBinding(
      contentBytes: videoBytes,
      certificate: certificate,
      tempDir: tempDir,
    );
  } catch (_) {
    return 'ERROR';
  }
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hcvpack_release_gate_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('valid historical ZIP v2 shape is verified', () async {
    final media = utf8.encode('original-certified-video-bytes');
    final certificate = _buildCertificate(media);
    final pack = _buildV2Pack(mediaBytes: media, certificate: certificate);

    expect(await _verifyOfflinePack(pack, tempDir), 'HUMAN VERIFIED');
  });

  test('modified or re-encoded media is rejected after metadata recompute',
      () async {
    final original = utf8.encode('original-certified-video-bytes');
    final modified = utf8.encode('re-encoded-video-with-different-bytes');
    final certificate = _buildCertificate(original);
    final pack = _buildV2Pack(
      mediaBytes: modified,
      certificate: certificate,
      metaMediaBytes: modified,
    );

    expect(await _verifyOfflinePack(pack, tempDir), 'TAMPERED');
  });

  test('truncated media is rejected after metadata recompute', () async {
    final original = utf8.encode('original-certified-video-bytes');
    final truncated = original.sublist(0, original.length - 6);
    final certificate = _buildCertificate(original);
    final pack = _buildV2Pack(
      mediaBytes: truncated,
      certificate: certificate,
      metaMediaBytes: truncated,
    );

    expect(await _verifyOfflinePack(pack, tempDir), 'TAMPERED');
  });

  test('altered certificate is rejected after metadata recompute', () async {
    final media = utf8.encode('original-certified-video-bytes');
    final certificate = _buildCertificate(media);
    final altered = Map<String, dynamic>.from(certificate);
    altered['claims'] = <String, dynamic>{
      ...(certificate['claims'] as Map<String, dynamic>),
      'captureSource': 'ALTERED_AFTER_SIGNATURE',
    };
    final pack = _buildV2Pack(
      mediaBytes: media,
      certificate: altered,
      metaCertificate: altered,
    );

    expect(await _verifyOfflinePack(pack, tempDir), 'INVALID');
  });

  test('package with missing certificate fails closed', () async {
    final media = utf8.encode('original-certified-video-bytes');
    final certificate = _buildCertificate(media);
    final pack = _buildV2Pack(
      mediaBytes: media,
      certificate: certificate,
      includeCertificate: false,
    );

    expect(await _verifyOfflinePack(pack, tempDir), 'ERROR');
  });

  test('corrupt non-ZIP/non-JSON package fails closed', () async {
    expect(
      await _verifyOfflinePack(utf8.encode('this is not an HCVPACK'), tempDir),
      'ERROR',
    );
  });

  test('legacy JSON video plus certificate remains compatible', () async {
    final media = utf8.encode('original-certified-video-bytes');
    final certificate = _buildCertificate(media);
    final legacy = utf8.encode(jsonEncode(<String, dynamic>{
      'video': base64Encode(media),
      'certificate': certificate,
    }));

    expect(await _verifyOfflinePack(legacy, tempDir), 'HUMAN VERIFIED');
  });
}
