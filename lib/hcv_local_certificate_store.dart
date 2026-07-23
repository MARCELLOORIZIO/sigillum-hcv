import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HCVLocalCertificateRecord {
  const HCVLocalCertificateRecord({
    required this.hcvId,
    required this.path,
    required this.sha256,
    required this.savedAt,
    required this.registryConfirmed,
  });

  final String hcvId;
  final String path;
  final String sha256;
  final String savedAt;
  final bool registryConfirmed;

  Map<String, dynamic> toJson() => {
        'hcvId': hcvId,
        'path': path,
        'sha256': sha256,
        'savedAt': savedAt,
        'registryConfirmed': registryConfirmed,
      };

  static HCVLocalCertificateRecord? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final hcvId = map['hcvId']?.toString() ?? '';
    final path = map['path']?.toString() ?? '';
    final digest = map['sha256']?.toString() ?? '';
    final savedAt = map['savedAt']?.toString() ?? '';
    if (hcvId.isEmpty || path.isEmpty || digest.isEmpty) return null;
    return HCVLocalCertificateRecord(
      hcvId: hcvId,
      path: path,
      sha256: digest,
      savedAt: savedAt,
      registryConfirmed: map['registryConfirmed'] == true,
    );
  }
}

class HCVLocalCertificateStore {
  static const _indexKey = 'hcv_local_certificate_index_v2';

  const HCVLocalCertificateStore();

  Future<Directory> _directory() async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory(p.join(root.path, 'sigillum', 'certificates'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  String? extractHcvId(Map<String, dynamic> certificate) {
    final meta = certificate['meta'];
    if (meta is Map && meta['hcvId'] != null) {
      return meta['hcvId'].toString().trim().toUpperCase();
    }
    return certificate['hcvId']?.toString().trim().toUpperCase();
  }

  Future<HCVLocalCertificateRecord> saveCertificateFile(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw FileSystemException('Certificato non trovato', sourcePath);
    }
    final raw = await source.readAsString();
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Certificato HCV non valido');
    }
    final hcvId = extractHcvId(decoded);
    if (hcvId == null || hcvId.isEmpty) {
      throw const FormatException('HCV-ID mancante');
    }
    final digest = sha256.convert(utf8.encode(raw)).toString();
    final safeId = hcvId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    final dir = await _directory();
    final target = File(p.join(dir.path, '$safeId.hcv'));
    final temp = File('${target.path}.tmp');
    await temp.writeAsString(raw, flush: true);
    if (await target.exists()) await target.delete();
    await temp.rename(target.path);

    final current = await getRecord(hcvId);
    final record = HCVLocalCertificateRecord(
      hcvId: hcvId,
      path: target.path,
      sha256: digest,
      savedAt: DateTime.now().toUtc().toIso8601String(),
      registryConfirmed: current?.registryConfirmed ?? false,
    );
    await _upsertRecord(record);
    return record;
  }

  Future<Map<String, dynamic>?> loadCertificate(String hcvId) async {
    final record = await getRecord(hcvId);
    if (record == null) return null;
    final file = File(record.path);
    if (!await file.exists()) return null;
    try {
      final raw = await file.readAsString();
      if (sha256.convert(utf8.encode(raw)).toString() != record.sha256) {
        return null;
      }
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }

  Future<HCVLocalCertificateRecord?> getRecord(String hcvId) async {
    final index = await _readIndex();
    return HCVLocalCertificateRecord.fromJson(
      index[hcvId.trim().toUpperCase()],
    );
  }

  Future<void> markRegistryConfirmed(
    String hcvId, {
    required bool confirmed,
  }) async {
    final record = await getRecord(hcvId);
    if (record == null) return;
    await _upsertRecord(HCVLocalCertificateRecord(
      hcvId: record.hcvId,
      path: record.path,
      sha256: record.sha256,
      savedAt: record.savedAt,
      registryConfirmed: confirmed,
    ));
  }

  Future<void> _upsertRecord(HCVLocalCertificateRecord record) async {
    final index = await _readIndex();
    index[record.hcvId] = record.toJson();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_indexKey, jsonEncode(index));
  }

  Future<Map<String, dynamic>> _readIndex() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_indexKey);
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return <String, dynamic>{};
  }
}
