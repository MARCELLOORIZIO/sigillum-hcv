import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'hcv_identity.dart';
import 'hcv_keystore_signer.dart';
import 'hcv_local_certificate_store.dart';
import 'hcv_verifier.dart';

class HCVEngine {
  final List<Map<String, dynamic>> chain = [];

  final String sessionId = const Uuid().v4();
  final String createdAt = DateTime.now().toUtc().toIso8601String();
  final String hcvId =
      'HCV-${const Uuid().v4().split('-').first.toUpperCase()}';

  Map<String, dynamic> meta = {
    'app': 'sigillum_hcv',
    'format': 'HCV',
    'version': '2.1.0',
    'device': Platform.operatingSystem,
  };

  Map<String, dynamic> claims = {};
  Map<String, dynamic>? liveSignals;
  Map<String, dynamic>? content;

  void setClaims(Map<String, dynamic> value) {
    claims = value;
  }

  void setLiveSignals(Map<String, dynamic> value) {
    liveSignals = value;
  }

  void start() => _addEvent('START');
  void stop() => _addEvent('STOP');

  void setContent({
    required String type,
    required String hash,
    int? size,
    String? name,
  }) {
    content = {
      'type': type,
      'hash': hash,
      if (size != null) 'size': size,
      if (name != null) 'name': name,
    };
    _addEvent('CONTENT_BOUND');
  }

  void _addEvent(String type) {
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final prevHash = chain.isEmpty ? 'GENESIS' : chain.last['hash'];
    final event = <String, dynamic>{
      'type': type,
      'timestamp': timestamp,
      'prev': prevHash,
    };
    event['hash'] = _computeHash(event);
    chain.add(event);
  }

  String _computeHash(Map<String, dynamic> data) {
    return sha256.convert(utf8.encode(jsonEncode(data))).toString();
  }

  String _computeRootHash() {
    return sha256.convert(utf8.encode(jsonEncode(chain))).toString();
  }

  Future<void> _attachIdentity() async {
    final identity = await HCVIdentity().loadIdentity(
      attemptKycRecovery: false,
    );
    meta = {...meta, 'identity': identity};
  }

  void _attachPublishData() {
    meta = {
      ...meta,
      'hcvId': hcvId,
      'verificationUrl': 'hcv://verify/$hcvId',
      'publishMode': 'MEDIA_PLUS_LOCAL_CERTIFICATE_PLUS_ONLINE_REGISTRY',
    };
  }

  Map<String, dynamic> _buildSignedPayload({required String rootHash}) {
    return {
      'format': 'HCV_CERTIFICATE',
      'version': 2,
      'sessionId': sessionId,
      'createdAt': createdAt,
      'meta': meta,
      'content': content,
      'claims': claims,
      if (liveSignals != null) 'liveSignals': liveSignals,
      'rootHash': rootHash,
      'chain': chain,
    };
  }

  Future<String> exportToFile() async {
    if (content == null) throw Exception('Content non impostato');
    if (chain.isEmpty || chain.first['type'] != 'START') {
      throw Exception('Catena HCV non avviata');
    }
    if (chain.last['type'] != 'STOP') {
      throw Exception('Catena HCV non chiusa');
    }

    await _attachIdentity();
    _attachPublishData();

    final dir = Platform.isAndroid
        ? Directory('/storage/emulated/0/Download')
        : await getApplicationDocumentsDirectory();
    if (!await dir.exists()) await dir.create(recursive: true);

    final signedPayload = _buildSignedPayload(rootHash: _computeRootHash());
    final canonical = jsonEncode(signedPayload);
    final payload = {
      ...signedPayload,
      'signatureAlgorithm': 'RSA-SHA256-HCV-V2',
      'signature': await HCVKeystoreSigner.sign(canonical),
      'publicKey': await HCVKeystoreSigner.getPublicKey(),
    };

    final file = File(
      p.join(dir.path, 'hcv_${DateTime.now().millisecondsSinceEpoch}.hcv'),
    );
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
      flush: true,
    );

    final valid = await HCVVerifier().verifyFile(file.path);
    if (!valid) {
      try {
        await file.delete();
      } catch (_) {}
      throw Exception('Il certificato generato non supera la verifica RSA locale');
    }

    await const HCVLocalCertificateStore().saveCertificateFile(file.path);
    return file.path;
  }
}
