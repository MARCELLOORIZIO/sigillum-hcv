import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'hcv_identity.dart';
import 'hcv_secure_store.dart';

class HCVSecureOriginalRecord {
  const HCVSecureOriginalRecord({
    required this.hcvId,
    required this.ownerCreatorId,
    required this.mediaType,
    required this.originalName,
    required this.mediaSha256,
    required this.mediaSize,
    required this.encryptedMediaPath,
    required this.hcvpackSha256,
    required this.hcvpackSize,
    required this.encryptedHcvpackPath,
    required this.certificatePath,
    required this.createdAt,
    this.publicationId,
    this.referenceUrl,
    this.referenceSha256,
    this.publishedAt,
  });

  final String hcvId;
  final String ownerCreatorId;
  final String mediaType;
  final String originalName;
  final String mediaSha256;
  final int mediaSize;
  final String encryptedMediaPath;
  final String hcvpackSha256;
  final int hcvpackSize;
  final String encryptedHcvpackPath;
  final String certificatePath;
  final DateTime createdAt;
  final String? publicationId;
  final String? referenceUrl;
  final String? referenceSha256;
  final DateTime? publishedAt;

  bool get hasReference =>
      publicationId != null &&
      publicationId!.isNotEmpty &&
      referenceUrl != null &&
      referenceUrl!.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'hcvId': hcvId,
        'ownerCreatorId': ownerCreatorId,
        'mediaType': mediaType,
        'originalName': originalName,
        'mediaSha256': mediaSha256,
        'mediaSize': mediaSize,
        'encryptedMediaPath': encryptedMediaPath,
        'hcvpackSha256': hcvpackSha256,
        'hcvpackSize': hcvpackSize,
        'encryptedHcvpackPath': encryptedHcvpackPath,
        'certificatePath': certificatePath,
        'createdAt': createdAt.toUtc().toIso8601String(),
        if (publicationId != null) 'publicationId': publicationId,
        if (referenceUrl != null) 'referenceUrl': referenceUrl,
        if (referenceSha256 != null) 'referenceSha256': referenceSha256,
        if (publishedAt != null)
          'publishedAt': publishedAt!.toUtc().toIso8601String(),
      };

  factory HCVSecureOriginalRecord.fromJson(Map<String, dynamic> json) {
    return HCVSecureOriginalRecord(
      hcvId: json['hcvId']?.toString() ?? '',
      ownerCreatorId: json['ownerCreatorId']?.toString() ?? '',
      mediaType: json['mediaType']?.toString() ?? '',
      originalName: json['originalName']?.toString() ?? '',
      mediaSha256: json['mediaSha256']?.toString() ?? '',
      mediaSize: (json['mediaSize'] as num?)?.toInt() ?? 0,
      encryptedMediaPath: json['encryptedMediaPath']?.toString() ?? '',
      hcvpackSha256: json['hcvpackSha256']?.toString() ?? '',
      hcvpackSize: (json['hcvpackSize'] as num?)?.toInt() ?? 0,
      encryptedHcvpackPath: json['encryptedHcvpackPath']?.toString() ?? '',
      certificatePath: json['certificatePath']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      publicationId: json['publicationId']?.toString(),
      referenceUrl: json['referenceUrl']?.toString(),
      referenceSha256: json['referenceSha256']?.toString(),
      publishedAt: DateTime.tryParse(json['publishedAt']?.toString() ?? ''),
    );
  }
}

class HCVSecureMediaVault {
  const HCVSecureMediaVault();

  static const String _masterKeyStoreKey = 'sigillum.secure.vault.master.v1';
  static const String _magic = 'SIGVLT1';
  static const int _version = 1;
  static const int _chunkSize = 4 * 1024 * 1024;
  static const int _macLength = 16;
  static final RegExp _hcvPattern = RegExp(r'^HCV-[A-F0-9]{16}$');
  static final RegExp _shaPattern = RegExp(r'^[a-f0-9]{64}$');
  static Future<void> _indexTail = Future<void>.value();

  Future<Directory> _vaultDirectory() async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory(p.join(root.path, 'sigillum_secure_originals_v1'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _indexFile() async {
    final dir = await _vaultDirectory();
    return File(p.join(dir.path, 'index.json'));
  }

  Future<String> _currentCreatorId() async {
    final identity = await HCVIdentity().loadIdentity();
    final creatorId = identity['creatorId']?.toString().trim() ?? '';
    if (creatorId.isEmpty) {
      throw StateError('SECURE_VAULT_CREATOR_ID_UNAVAILABLE');
    }
    return creatorId;
  }

  Future<SecretKey> _masterKey() async {
    final existing = await HCVSecureStore.read(_masterKeyStoreKey);
    if (existing != null && existing.isNotEmpty) {
      final bytes = base64Decode(existing);
      if (bytes.length != 32) {
        throw StateError('SECURE_VAULT_MASTER_KEY_INVALID');
      }
      return SecretKey(bytes);
    }

    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    await HCVSecureStore.write(_masterKeyStoreKey, base64Encode(bytes));
    return SecretKey(bytes);
  }

  Future<String> _sha256File(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  Uint8List _nonce(List<int> baseNonce, int counter) {
    if (baseNonce.length != 8 || counter < 0 || counter > 0xffffffff) {
      throw StateError('SECURE_VAULT_NONCE_INVALID');
    }
    final nonce = Uint8List(12)..setRange(0, 8, baseNonce);
    final view = ByteData.sublistView(nonce);
    view.setUint32(8, counter, Endian.big);
    return nonce;
  }

  Future<void> _encryptFile({
    required File source,
    required File destination,
    required String sha256Hex,
    required String mimeType,
    required String originalName,
  }) async {
    final algorithm = AesGcm.with256bits();
    final key = await _masterKey();
    final random = Random.secure();
    final baseNonce = List<int>.generate(8, (_) => random.nextInt(256));
    final plainLength = await source.length();
    final header = <String, dynamic>{
      'version': _version,
      'chunkSize': _chunkSize,
      'plainLength': plainLength,
      'sha256': sha256Hex,
      'mimeType': mimeType,
      'originalName': originalName,
      'baseNonce': base64Encode(baseNonce),
    };

    final input = await source.open();
    final output = await destination.open(mode: FileMode.write);
    try {
      await output.writeString('$_magic\n${jsonEncode(header)}\n');
      var remaining = plainLength;
      var counter = 0;
      while (remaining > 0) {
        final wanted = min(_chunkSize, remaining);
        final chunk = await input.read(wanted);
        if (chunk.length != wanted) {
          throw StateError('SECURE_VAULT_SOURCE_TRUNCATED');
        }
        final box = await algorithm.encrypt(
          chunk,
          secretKey: key,
          nonce: _nonce(baseNonce, counter),
        );
        if (box.mac.bytes.length != _macLength) {
          throw StateError('SECURE_VAULT_MAC_INVALID');
        }
        await output.writeFrom(box.cipherText);
        await output.writeFrom(box.mac.bytes);
        remaining -= wanted;
        counter += 1;
      }
      await output.flush();
    } finally {
      await input.close();
      await output.close();
    }
  }

  Future<String> _readLine(RandomAccessFile file, {int maxBytes = 8192}) async {
    final bytes = <int>[];
    while (bytes.length < maxBytes) {
      final value = await file.readByte();
      if (value == -1) break;
      if (value == 10) return utf8.decode(bytes);
      bytes.add(value);
    }
    throw StateError('SECURE_VAULT_HEADER_INVALID');
  }

  Future<Map<String, dynamic>> _readHeader(RandomAccessFile input) async {
    final magic = await _readLine(input);
    if (magic != _magic) throw StateError('SECURE_VAULT_FORMAT_INVALID');
    final raw = await _readLine(input);
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('SECURE_VAULT_HEADER_INVALID');
    }
    if (decoded['version'] != _version ||
        decoded['chunkSize'] != _chunkSize ||
        decoded['plainLength'] is! num ||
        decoded['sha256'] is! String ||
        !_shaPattern.hasMatch(decoded['sha256']) ||
        decoded['baseNonce'] is! String) {
      throw StateError('SECURE_VAULT_HEADER_INVALID');
    }
    final nonce = base64Decode(decoded['baseNonce']);
    if (nonce.length != 8) throw StateError('SECURE_VAULT_NONCE_INVALID');
    return decoded;
  }

  Future<void> _decryptFile({
    required File encrypted,
    required File destination,
    required String expectedSha256,
  }) async {
    final algorithm = AesGcm.with256bits();
    final key = await _masterKey();
    final input = await encrypted.open();
    final output = await destination.open(mode: FileMode.write);
    try {
      final header = await _readHeader(input);
      final plainLength = (header['plainLength'] as num).toInt();
      final headerHash = header['sha256'] as String;
      final baseNonce = base64Decode(header['baseNonce'] as String);
      if (plainLength <= 0 ||
          headerHash != expectedSha256 ||
          !_shaPattern.hasMatch(expectedSha256)) {
        throw StateError('SECURE_VAULT_BINDING_MISMATCH');
      }

      var remaining = plainLength;
      var counter = 0;
      while (remaining > 0) {
        final plainChunkLength = min(_chunkSize, remaining);
        final cipherText = await input.read(plainChunkLength);
        final macBytes = await input.read(_macLength);
        if (cipherText.length != plainChunkLength ||
            macBytes.length != _macLength) {
          throw StateError('SECURE_VAULT_CIPHERTEXT_TRUNCATED');
        }
        final clear = await algorithm.decrypt(
          SecretBox(
            cipherText,
            nonce: _nonce(baseNonce, counter),
            mac: Mac(macBytes),
          ),
          secretKey: key,
        );
        if (clear.length != plainChunkLength) {
          throw StateError('SECURE_VAULT_DECRYPT_LENGTH_INVALID');
        }
        await output.writeFrom(clear);
        remaining -= plainChunkLength;
        counter += 1;
      }
      if (await input.position() != await input.length()) {
        throw StateError('SECURE_VAULT_TRAILING_DATA');
      }
      await output.flush();
    } finally {
      await input.close();
      await output.close();
    }

    final actual = await _sha256File(destination);
    if (actual != expectedSha256) {
      try {
        await destination.delete();
      } catch (_) {}
      throw StateError('SECURE_VAULT_PLAINTEXT_HASH_MISMATCH');
    }
  }

  Future<List<HCVSecureOriginalRecord>> _loadIndex() async {
    final file = await _indexFile();
    if (!await file.exists()) return <HCVSecureOriginalRecord>[];
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) return <HCVSecureOriginalRecord>[];
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic> || decoded['records'] is! List) {
      throw StateError('SECURE_VAULT_INDEX_INVALID');
    }
    return (decoded['records'] as List)
        .whereType<Map>()
        .map((item) => HCVSecureOriginalRecord.fromJson(
              Map<String, dynamic>.from(item),
            ))
        .where((item) =>
            _hcvPattern.hasMatch(item.hcvId) &&
            _shaPattern.hasMatch(item.mediaSha256) &&
            _shaPattern.hasMatch(item.hcvpackSha256))
        .toList();
  }

  Future<void> _saveIndex(List<HCVSecureOriginalRecord> records) async {
    final file = await _indexFile();
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(
      jsonEncode({
        'schema': 'SIGILLUM_SECURE_ORIGINALS_INDEX',
        'version': 1,
        'records': records.map((item) => item.toJson()).toList(),
      }),
      flush: true,
    );
    if (await file.exists()) await file.delete();
    await temp.rename(file.path);
  }

  Future<T> _withIndexLock<T>(Future<T> Function() action) {
    final previous = _indexTail;
    final release = Completer<void>();
    _indexTail = release.future;
    return () async {
      await previous;
      try {
        return await action();
      } finally {
        if (!release.isCompleted) release.complete();
      }
    }();
  }

  Future<HCVSecureOriginalRecord> seal({
    required String hcvId,
    required String mediaType,
    required String mediaPath,
    required String hcvpackPath,
    required String certificatePath,
    required String expectedMediaSha256,
  }) async {
    final cleanId = hcvId.trim().toUpperCase();
    if (!_hcvPattern.hasMatch(cleanId) ||
        (mediaType != 'video' && mediaType != 'photo') ||
        !_shaPattern.hasMatch(expectedMediaSha256)) {
      throw ArgumentError('SECURE_VAULT_INPUT_INVALID');
    }

    final ownerCreatorId = await _currentCreatorId();
    final media = File(mediaPath);
    final pack = File(hcvpackPath);
    final certificate = File(certificatePath);
    if (!await media.exists() ||
        !await pack.exists() ||
        !await certificate.exists()) {
      throw StateError('SECURE_VAULT_SOURCE_MISSING');
    }

    final mediaHash = await _sha256File(media);
    if (mediaHash != expectedMediaSha256) {
      throw StateError('SECURE_VAULT_MEDIA_HASH_MISMATCH');
    }
    final packHash = await _sha256File(pack);
    final mediaSize = await media.length();
    final packSize = await pack.length();
    if (mediaSize <= 0 || packSize <= 0) {
      throw StateError('SECURE_VAULT_SOURCE_EMPTY');
    }

    final dir = await _vaultDirectory();
    final safe = cleanId.replaceAll(RegExp(r'[^A-Z0-9-]'), '');
    final encryptedMedia = File(p.join(dir.path, '$safe.media.enc'));
    final encryptedPack = File(p.join(dir.path, '$safe.hcvpack.enc'));
    for (final target in [encryptedMedia, encryptedPack]) {
      if (await target.exists()) await target.delete();
    }

    try {
      await _encryptFile(
        source: media,
        destination: encryptedMedia,
        sha256Hex: mediaHash,
        mimeType: mediaType == 'video' ? 'video/mp4' : _photoMime(media.path),
        originalName: p.basename(media.path),
      );
      await _encryptFile(
        source: pack,
        destination: encryptedPack,
        sha256Hex: packHash,
        mimeType: 'application/vnd.sigillum.hcvpack',
        originalName: p.basename(pack.path),
      );

      final record = HCVSecureOriginalRecord(
        hcvId: cleanId,
        ownerCreatorId: ownerCreatorId,
        mediaType: mediaType,
        originalName: p.basename(media.path),
        mediaSha256: mediaHash,
        mediaSize: mediaSize,
        encryptedMediaPath: encryptedMedia.path,
        hcvpackSha256: packHash,
        hcvpackSize: packSize,
        encryptedHcvpackPath: encryptedPack.path,
        certificatePath: certificate.absolute.path,
        createdAt: DateTime.now().toUtc(),
      );

      await _withIndexLock(() async {
        final records = await _loadIndex();
        final existing = records.where((item) => item.hcvId == cleanId).toList();
        if (existing.isNotEmpty &&
            (existing.first.ownerCreatorId != ownerCreatorId ||
                existing.first.mediaSha256 != mediaHash ||
                existing.first.hcvpackSha256 != packHash)) {
          throw StateError('SECURE_VAULT_HCV_CONFLICT');
        }
        records.removeWhere((item) => item.hcvId == cleanId);
        records.add(record);
        records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        await _saveIndex(records);
      });

      await media.delete();
      await pack.delete();
      return record;
    } catch (_) {
      for (final target in [encryptedMedia, encryptedPack]) {
        try {
          if (await target.exists()) await target.delete();
        } catch (_) {}
      }
      rethrow;
    }
  }

  Future<List<HCVSecureOriginalRecord>> list() async {
    final ownerCreatorId = await _currentCreatorId();
    return _withIndexLock(() async {
      final records = await _loadIndex();
      final available = <HCVSecureOriginalRecord>[];
      for (final item in records) {
        if (item.ownerCreatorId == ownerCreatorId &&
            await File(item.encryptedMediaPath).exists() &&
            await File(item.encryptedHcvpackPath).exists()) {
          available.add(item);
        }
      }
      return available;
    });
  }

  Future<HCVSecureOriginalRecord?> find(String hcvId) async {
    final clean = hcvId.trim().toUpperCase();
    final records = await list();
    for (final item in records) {
      if (item.hcvId == clean) return item;
    }
    return null;
  }

  Future<File> materializeOriginal(
    HCVSecureOriginalRecord record, {
    String purpose = 'view',
  }) async {
    if (record.ownerCreatorId != await _currentCreatorId()) {
      throw StateError('SECURE_VAULT_CREATOR_MISMATCH');
    }
    final tempRoot = await getTemporaryDirectory();
    final dir = Directory(p.join(tempRoot.path, 'sigillum_secure_materialized'));
    if (!await dir.exists()) await dir.create(recursive: true);
    final extension = p.extension(record.originalName).isEmpty
        ? (record.mediaType == 'video' ? '.mp4' : '.jpg')
        : p.extension(record.originalName);
    final target = File(
      p.join(
        dir.path,
        '${record.hcvId}_${purpose}_${DateTime.now().microsecondsSinceEpoch}$extension',
      ),
    );
    await _decryptFile(
      encrypted: File(record.encryptedMediaPath),
      destination: target,
      expectedSha256: record.mediaSha256,
    );
    return target;
  }

  Future<File> materializeHcvpack(
    HCVSecureOriginalRecord record, {
    String purpose = 'export',
  }) async {
    if (record.ownerCreatorId != await _currentCreatorId()) {
      throw StateError('SECURE_VAULT_CREATOR_MISMATCH');
    }
    final tempRoot = await getTemporaryDirectory();
    final dir = Directory(p.join(tempRoot.path, 'sigillum_secure_materialized'));
    if (!await dir.exists()) await dir.create(recursive: true);
    final target = File(
      p.join(
        dir.path,
        '${record.hcvId}_${purpose}_${DateTime.now().microsecondsSinceEpoch}.hcvpack',
      ),
    );
    await _decryptFile(
      encrypted: File(record.encryptedHcvpackPath),
      destination: target,
      expectedSha256: record.hcvpackSha256,
    );
    return target;
  }

  Future<void> markReference({
    required String hcvId,
    required String publicationId,
    required String referenceUrl,
    required String referenceSha256,
  }) async {
    if (!_shaPattern.hasMatch(referenceSha256)) {
      throw ArgumentError('SECURE_VAULT_REFERENCE_HASH_INVALID');
    }
    await _withIndexLock(() async {
      final records = await _loadIndex();
      final index = records.indexWhere((item) => item.hcvId == hcvId);
      if (index < 0) throw StateError('SECURE_VAULT_RECORD_NOT_FOUND');
      final current = records[index];
      records[index] = HCVSecureOriginalRecord(
        hcvId: current.hcvId,
        ownerCreatorId: current.ownerCreatorId,
        mediaType: current.mediaType,
        originalName: current.originalName,
        mediaSha256: current.mediaSha256,
        mediaSize: current.mediaSize,
        encryptedMediaPath: current.encryptedMediaPath,
        hcvpackSha256: current.hcvpackSha256,
        hcvpackSize: current.hcvpackSize,
        encryptedHcvpackPath: current.encryptedHcvpackPath,
        certificatePath: current.certificatePath,
        createdAt: current.createdAt,
        publicationId: publicationId,
        referenceUrl: referenceUrl,
        referenceSha256: referenceSha256,
        publishedAt: DateTime.now().toUtc(),
      );
      await _saveIndex(records);
    });
  }

  Future<void> deleteMaterialized(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  String _photoMime(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    return 'image/jpeg';
  }
}
