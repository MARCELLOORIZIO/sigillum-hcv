import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcvpack_player_page.dart';

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

Future<void> _pumpPack(
  WidgetTester tester,
  List<int> packBytes,
  Directory dir,
) async {
  final file = File('${dir.path}/release_gate.hcvpack');
  await file.writeAsBytes(packBytes, flush: true);

  await tester.pumpWidget(
    MaterialApp(
      home: HCVPackPlayerPage(
        initialPath: file.path,
        languageCode: 'it',
      ),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hcvpack_release_gate_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
      if (call.method == 'getTemporaryDirectory' ||
          call.method == 'getApplicationDocumentsDirectory') {
        return tempDir.path;
      }
      return tempDir.path;
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('valid historical ZIP v2 shape reaches HUMAN VERIFIED',
      (tester) async {
    final media = utf8.encode('original-certified-video-bytes');
    final certificate = _buildCertificate(media);
    final pack = _buildV2Pack(mediaBytes: media, certificate: certificate);

    await _pumpPack(tester, pack, tempDir);

    expect(find.text('HUMAN VERIFIED'), findsOneWidget);
    expect(find.text('NOT VERIFIED'), findsNothing);
  });

  testWidgets(
      'modified or re-encoded media is rejected even if attacker recomputes package metadata',
      (tester) async {
    final original = utf8.encode('original-certified-video-bytes');
    final modified = utf8.encode('re-encoded-video-with-different-bytes');
    final certificate = _buildCertificate(original);
    final pack = _buildV2Pack(
      mediaBytes: modified,
      certificate: certificate,
      metaMediaBytes: modified,
    );

    await _pumpPack(tester, pack, tempDir);

    expect(find.text('NOT VERIFIED'), findsOneWidget);
    expect(find.text('TAMPERED'), findsOneWidget);
    expect(find.text('Contenuto modificato'), findsOneWidget);
  });

  testWidgets(
      'altered certificate is rejected even if attacker recomputes package metadata',
      (tester) async {
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

    await _pumpPack(tester, pack, tempDir);

    expect(find.text('NOT VERIFIED'), findsOneWidget);
    expect(find.text('INVALID'), findsOneWidget);
  });

  testWidgets('package with missing certificate fails closed', (tester) async {
    final media = utf8.encode('original-certified-video-bytes');
    final certificate = _buildCertificate(media);
    final pack = _buildV2Pack(
      mediaBytes: media,
      certificate: certificate,
      includeCertificate: false,
    );

    await _pumpPack(tester, pack, tempDir);

    expect(find.text('NOT VERIFIED'), findsOneWidget);
    expect(find.text('ERROR'), findsOneWidget);
  });

  testWidgets('corrupt non-ZIP/non-JSON package fails closed', (tester) async {
    await _pumpPack(
      tester,
      utf8.encode('this is not an HCVPACK'),
      tempDir,
    );

    expect(find.text('NOT VERIFIED'), findsOneWidget);
    expect(find.text('ERROR'), findsOneWidget);
  });

  testWidgets('legacy JSON video plus certificate remains compatible',
      (tester) async {
    final media = utf8.encode('original-certified-video-bytes');
    final certificate = _buildCertificate(media);
    final legacy = utf8.encode(jsonEncode(<String, dynamic>{
      'video': base64Encode(media),
      'certificate': certificate,
    }));

    await _pumpPack(tester, legacy, tempDir);

    expect(find.text('HUMAN VERIFIED'), findsOneWidget);
    expect(find.text('NOT VERIFIED'), findsNothing);
  });
}
