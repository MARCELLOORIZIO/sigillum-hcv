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
    required this.ownerAccountSubjectHash,
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
    this.captionedMediaSha256,
    this.captionedMediaSize,
    this.encryptedCaptionedMediaPath,
    this.subtitleSha256,
    this.subtitleSize,
    this.encryptedSubtitlePath,
    this.subtitlePublicationId,
    this.subtitleReferenceUrl,
    this.subtitleReferenceSha256,
    this.subtitlePublishedAt,
  });

  final String hcvId;
  final String ownerCreatorId;
  final String ownerAccountSubjectHash;
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
  final String? captionedMediaSha256;
  final int? captionedMediaSize;
  final String? encryptedCaptionedMediaPath;
  final String? subtitleSha256;
  final int? subtitleSize;
  final String? encryptedSubtitlePath;
  final String? subtitlePublicationId;
  final String? subtitleReferenceUrl;
  final String? subtitleReferenceSha256;
  final DateTime? subtitlePublishedAt;

  bool get hasSubtitleDerivative =>
      captionedMediaSha256 != null &&
      _shaLike(captionedMediaSha256!) &&
      encryptedCaptionedMediaPath != null &&
      encryptedCaptionedMediaPath!.isNotEmpty &&
      subtitleSha256 != null &&
      _shaLike(subtitleSha256!) &&
      encryptedSubtitlePath != null &&
      encryptedSubtitlePath!.isNotEmpty;

  bool get hasSubtitleReference =>
      subtitlePublicationId != null &&
      subtitlePublicationId!.isNotEmpty &&
      subtitleReferenceUrl != null &&
      subtitleReferenceUrl!.isNotEmpty &&
      subtitleReferenceSha256 != null &&
      _shaLike(subtitleReferenceSha256!);

  static bool _shaLike(String value) =>
      RegExp(r'^[a-f0-9]{64}$').hasMatch(value);

  bool get hasReference =>
      publicationId != null &&
      publicationId!.isNotEmpty &&
      referenceUrl != null &&
      referenceUrl!.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'hcvId': hcvId,
        'ownerCreatorId': ownerCreatorId,
        'ownerAccountSubjectHash': ownerAccountSubjectHash,
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
        if (captionedMediaSha256 != null)
          'captionedMediaSha256': captionedMediaSha256,
        if (captionedMediaSize != null)
          'captionedMediaSize': captionedMediaSize,
        if (encryptedCaptionedMediaPath != null)
          'encryptedCaptionedMediaPath': encryptedCaptionedMediaPath,
        if (subtitleSha256 != null) 'subtitleSha256': subtitleSha256,
        if (subtitleSize != null) 'subtitleSize': subtitleSize,
        if (encryptedSubtitlePath != null)
          'encryptedSubtitlePath': encryptedSubtitlePath,
        if (subtitlePublicationId != null)
          'subtitlePublicationId': subtitlePublicationId,
        if (subtitleReferenceUrl != null)
          'subtitleReferenceUrl': subtitleReferenceUrl,
        if (subtitleReferenceSha256 != null)
          'subtitleReferenceSha256': subtitleReferenceSha256,
        if (subtitlePublishedAt != null)
          'subtitlePublishedAt': subtitlePublishedAt!.toUtc().toIso8601String(),
      };

  factory HCVSecureOriginalRecord.fromJson(Map<String, dynamic> json) {
    return HCVSecureOriginalRecord(
      hcvId: json['hcvId']?.toString() ?? '',
      ownerCreatorId: json['ownerCreatorId']?.toString() ?? '',
      ownerAccountSubjectHash:
          json['ownerAccountSubjectHash']?.toString().toLowerCase() ?? '',
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
      captionedMediaSha256: json['captionedMediaSha256']?.toString(),
      captionedMediaSize: (json['captionedMediaSize'] as num?)?.toInt(),
      encryptedCaptionedMediaPath:
          json['encryptedCaptionedMediaPath']?.toString(),
      subtitleSha256: json['subtitleSha256']?.toString(),
      subtitleSize: (json['subtitleSize'] as num?)?.toInt(),
      encryptedSubtitlePath: json['encryptedSubtitlePath']?.toString(),
      subtitlePublicationId: json['subtitlePublicationId']?.toString(),
      subtitleReferenceUrl: json['subtitleReferenceUrl']?.toString(),
      subtitleReferenceSha256: json['subtitleReferenceSha256']?.toString(),
      subtitlePublishedAt:
          DateTime.tryParse(json['subtitlePublishedAt']?.toString() ?? ''),
    );
  }
}

class HCVSecureMediaVault {
  const HCVSecureMediaVault();

  static const String _masterKeyStoreKey = 'sigillum.secure.vault.master.v1';
  static const String _accountIdStoreKey = 'sigillum.auth.account.id.v1';
  static const String _magic = 'SIGVLT1';
  static const int _version = 1;
  static const int _chunkSize = 4 * 1024 * 1024;
  static const int _macLength = 16;
  static final RegExp _hcvPattern = RegExp(r'^HCV-[A-F0-9]{16}$');
  static final RegExp _shaPattern = RegExp(r'^[a-f0-9]{64}$');
  static Future<void> _indexTail = Future<void>.value();
  static Future<void> _pendingSealTail = Future<void>.value();

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

  Future<File> _pendingSealFile() async {
    final dir = await _vaultDirectory();
    return File(p.join(dir.path, 'pending_seals.json'));
  }

  Future<T> _withPendingSealLock<T>(Future<T> Function() action) {
    final previous = _pendingSealTail;
    final release = Completer<void>();
    _pendingSealTail = release.future;
    return () async {
      await previous;
      try {
        return await action();
      } finally {
        if (!release.isCompleted) release.complete();
      }
    }();
  }

  Future<List<Map<String, dynamic>>> _loadPendingSeals() async {
    final file = await _pendingSealFile();
    if (!await file.exists()) return <Map<String, dynamic>>[];
    try {
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return <Map<String, dynamic>>[];
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> || decoded['records'] is! List) {
        return <Map<String, dynamic>>[];
      }
      return (decoded['records'] as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> _savePendingSeals(List<Map<String, dynamic>> records) async {
    final file = await _pendingSealFile();
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(
      jsonEncode({
        'schema': 'SIGILLUM_PENDING_SEALS',
        'version': 1,
        'records': records,
      }),
      flush: true,
    );
    if (await file.exists()) await file.delete();
    await temp.rename(file.path);
  }

  Future<void> _upsertPendingSeal({
    required String hcvId,
    required String ownerCreatorId,
    required String ownerAccountSubjectHash,
    required String mediaType,
    required String mediaPath,
    required String hcvpackPath,
    required String certificatePath,
    required String expectedMediaSha256,
  }) {
    return _withPendingSealLock(() async {
      final records = await _loadPendingSeals();
      records.removeWhere((item) => item['hcvId']?.toString() == hcvId);
      records.add({
        'hcvId': hcvId,
        'ownerCreatorId': ownerCreatorId,
        'ownerAccountSubjectHash': ownerAccountSubjectHash,
        'mediaType': mediaType,
        'mediaPath': File(mediaPath).absolute.path,
        'hcvpackPath': File(hcvpackPath).absolute.path,
        'certificatePath': File(certificatePath).absolute.path,
        'expectedMediaSha256': expectedMediaSha256,
        'stagedAt': DateTime.now().toUtc().toIso8601String(),
      });
      await _savePendingSeals(records);
    });
  }

  Future<void> _removePendingSeal(String hcvId) {
    return _withPendingSealLock(() async {
      final records = await _loadPendingSeals();
      final before = records.length;
      records.removeWhere((item) => item['hcvId']?.toString() == hcvId);
      if (records.length != before) await _savePendingSeals(records);
    });
  }

  Future<String> _currentCreatorId() async {
    final identity = await HCVIdentity().loadIdentity();
    final creatorId = identity['creatorId']?.toString().trim() ?? '';
    if (creatorId.isEmpty) {
      throw StateError('SECURE_VAULT_CREATOR_ID_UNAVAILABLE');
    }
    return creatorId;
  }

  Future<String> _currentAccountSubjectHash() async {
    final accountId = await HCVSecureStore.read(_accountIdStoreKey);
    final clean = accountId?.trim() ?? '';
    if (clean.isEmpty) {
      throw StateError('SECURE_VAULT_ACCOUNT_CONTEXT_UNAVAILABLE');
    }
    return sha256.convert(utf8.encode(clean)).toString();
  }

  String _accountSubjectHash(String accountId) {
    final clean = accountId.trim();
    if (clean.isEmpty) {
      throw ArgumentError('SECURE_VAULT_ACCOUNT_ID_UNAVAILABLE');
    }
    return sha256.convert(utf8.encode(clean)).toString();
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
    try {
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
        throw StateError('SECURE_VAULT_PLAINTEXT_HASH_MISMATCH');
      }
    } catch (_) {
      try {
        if (await destination.exists()) await destination.delete();
      } catch (_) {}
      rethrow;
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
    final ownerAccountSubjectHash = await _currentAccountSubjectHash();
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

    await _upsertPendingSeal(
      hcvId: cleanId,
      ownerCreatorId: ownerCreatorId,
      ownerAccountSubjectHash: ownerAccountSubjectHash,
      mediaType: mediaType,
      mediaPath: media.absolute.path,
      hcvpackPath: pack.absolute.path,
      certificatePath: certificate.absolute.path,
      expectedMediaSha256: expectedMediaSha256,
    );

    final existingBefore = await _withIndexLock(() async {
      final records = await _loadIndex();
      for (final item in records) {
        if (item.hcvId == cleanId) return item;
      }
      return null;
    });

    if (existingBefore != null &&
        (existingBefore.ownerCreatorId != ownerCreatorId ||
            existingBefore.ownerAccountSubjectHash != ownerAccountSubjectHash ||
            existingBefore.mediaSha256 != mediaHash ||
            existingBefore.hcvpackSha256 != packHash)) {
      throw StateError('SECURE_VAULT_HCV_CONFLICT');
    }

    if (existingBefore != null &&
        await File(existingBefore.encryptedMediaPath).exists() &&
        await File(existingBefore.encryptedHcvpackPath).exists()) {
      await media.delete();
      await pack.delete();
      await _removePendingSeal(cleanId);
      return existingBefore;
    }

    final dir = await _vaultDirectory();
    final safe = cleanId.replaceAll(RegExp(r'[^A-Z0-9-]'), '');
    final mediaTag = mediaHash.substring(0, 16);
    final packTag = packHash.substring(0, 16);
    final encryptedMedia = File(p.join(dir.path, '$safe.$mediaTag.media.enc'));
    final encryptedPack = File(p.join(dir.path, '$safe.$packTag.hcvpack.enc'));

    for (final target in [encryptedMedia, encryptedPack]) {
      if (await target.exists()) await target.delete();
    }

    final record = HCVSecureOriginalRecord(
      hcvId: cleanId,
      ownerCreatorId: ownerCreatorId,
      ownerAccountSubjectHash: ownerAccountSubjectHash,
      mediaType: mediaType,
      originalName: p.basename(media.path),
      mediaSha256: mediaHash,
      mediaSize: mediaSize,
      encryptedMediaPath: encryptedMedia.path,
      hcvpackSha256: packHash,
      hcvpackSize: packSize,
      encryptedHcvpackPath: encryptedPack.path,
      certificatePath: certificate.absolute.path,
      createdAt: existingBefore?.createdAt ?? DateTime.now().toUtc(),
      publicationId: existingBefore?.publicationId,
      referenceUrl: existingBefore?.referenceUrl,
      referenceSha256: existingBefore?.referenceSha256,
      publishedAt: existingBefore?.publishedAt,
      captionedMediaSha256: existingBefore?.captionedMediaSha256,
      captionedMediaSize: existingBefore?.captionedMediaSize,
      encryptedCaptionedMediaPath: existingBefore?.encryptedCaptionedMediaPath,
      subtitleSha256: existingBefore?.subtitleSha256,
      subtitleSize: existingBefore?.subtitleSize,
      encryptedSubtitlePath: existingBefore?.encryptedSubtitlePath,
      subtitlePublicationId: existingBefore?.subtitlePublicationId,
      subtitleReferenceUrl: existingBefore?.subtitleReferenceUrl,
      subtitleReferenceSha256: existingBefore?.subtitleReferenceSha256,
      subtitlePublishedAt: existingBefore?.subtitlePublishedAt,
    );

    var committed = false;
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

      await _withIndexLock(() async {
        final records = await _loadIndex();
        final existing =
            records.where((item) => item.hcvId == cleanId).toList();
        if (existing.isNotEmpty &&
            (existing.first.ownerCreatorId != ownerCreatorId ||
                existing.first.ownerAccountSubjectHash !=
                    ownerAccountSubjectHash ||
                existing.first.mediaSha256 != mediaHash ||
                existing.first.hcvpackSha256 != packHash)) {
          throw StateError('SECURE_VAULT_HCV_CONFLICT');
        }
        records.removeWhere((item) => item.hcvId == cleanId);
        records.add(record);
        records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        await _saveIndex(records);
      });
      committed = true;
    } finally {
      if (!committed) {
        for (final target in [encryptedMedia, encryptedPack]) {
          try {
            if (await target.exists()) await target.delete();
          } catch (_) {}
        }
      }
    }

    await media.delete();
    await pack.delete();
    await _removePendingSeal(cleanId);
    return record;
  }

  Future<int> recoverPendingSeals() async {
    final ownerCreatorId = await _currentCreatorId();
    final ownerAccountSubjectHash = await _currentAccountSubjectHash();
    final pending = await _withPendingSealLock(_loadPendingSeals);
    var recovered = 0;

    for (final item in pending) {
      final hcvId = item['hcvId']?.toString().trim().toUpperCase() ?? '';
      if (!_hcvPattern.hasMatch(hcvId) ||
          item['ownerCreatorId']?.toString() != ownerCreatorId ||
          item['ownerAccountSubjectHash']?.toString() !=
              ownerAccountSubjectHash) {
        continue;
      }

      final existing = await find(hcvId);
      if (existing != null) {
        await _removePendingSeal(hcvId);
        continue;
      }

      final mediaPath = item['mediaPath']?.toString() ?? '';
      final hcvpackPath = item['hcvpackPath']?.toString() ?? '';
      final certificatePath = item['certificatePath']?.toString() ?? '';
      final mediaType = item['mediaType']?.toString() ?? '';
      final expectedMediaSha256 =
          item['expectedMediaSha256']?.toString().toLowerCase() ?? '';

      if ((mediaType != 'video' && mediaType != 'photo') ||
          !_shaPattern.hasMatch(expectedMediaSha256) ||
          !await File(mediaPath).exists() ||
          !await File(hcvpackPath).exists() ||
          !await File(certificatePath).exists()) {
        continue;
      }

      try {
        await seal(
          hcvId: hcvId,
          mediaType: mediaType,
          mediaPath: mediaPath,
          hcvpackPath: hcvpackPath,
          certificatePath: certificatePath,
          expectedMediaSha256: expectedMediaSha256,
        );
        recovered++;
      } catch (_) {
        // Leave the journal entry intact. A later app start may recover it.
      }
    }
    return recovered;
  }

  Future<List<HCVSecureOriginalRecord>> list() async {
    final ownerCreatorId = await _currentCreatorId();
    final ownerAccountSubjectHash = await _currentAccountSubjectHash();
    return _withIndexLock(() async {
      final records = await _loadIndex();
      final available = <HCVSecureOriginalRecord>[];
      for (final item in records) {
        if (item.ownerCreatorId == ownerCreatorId &&
            item.ownerAccountSubjectHash == ownerAccountSubjectHash &&
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
    if (record.ownerAccountSubjectHash != await _currentAccountSubjectHash()) {
      throw StateError('SECURE_VAULT_ACCOUNT_MISMATCH');
    }
    final tempRoot = await getTemporaryDirectory();
    final dir =
        Directory(p.join(tempRoot.path, 'sigillum_secure_materialized'));
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
    if (record.ownerAccountSubjectHash != await _currentAccountSubjectHash()) {
      throw StateError('SECURE_VAULT_ACCOUNT_MISMATCH');
    }
    final tempRoot = await getTemporaryDirectory();
    final dir =
        Directory(p.join(tempRoot.path, 'sigillum_secure_materialized'));
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

  Future<HCVSecureOriginalRecord> sealSubtitleDerivative({
    required HCVSecureOriginalRecord original,
    required String captionedVideoPath,
    required String subtitlePath,
  }) async {
    if (original.mediaType != 'video') {
      throw ArgumentError('SECURE_VAULT_SUBTITLE_SOURCE_NOT_VIDEO');
    }
    if (original.ownerCreatorId != await _currentCreatorId() ||
        original.ownerAccountSubjectHash !=
            await _currentAccountSubjectHash()) {
      throw StateError('SECURE_VAULT_ACCOUNT_MISMATCH');
    }

    final captioned = File(captionedVideoPath);
    final subtitle = File(subtitlePath);
    if (!await captioned.exists() || !await subtitle.exists()) {
      throw StateError('SECURE_VAULT_SUBTITLE_SOURCE_MISSING');
    }

    final captionedHash = await _sha256File(captioned);
    final subtitleHash = await _sha256File(subtitle);
    final captionedSize = await captioned.length();
    final subtitleSize = await subtitle.length();
    if (captionedSize <= 0 || subtitleSize <= 0) {
      throw StateError('SECURE_VAULT_SUBTITLE_SOURCE_EMPTY');
    }

    final current = await find(original.hcvId);
    if (current == null) throw StateError('SECURE_VAULT_RECORD_NOT_FOUND');

    if (current.captionedMediaSha256 == captionedHash &&
        current.subtitleSha256 == subtitleHash &&
        current.encryptedCaptionedMediaPath != null &&
        current.encryptedSubtitlePath != null &&
        await File(current.encryptedCaptionedMediaPath!).exists() &&
        await File(current.encryptedSubtitlePath!).exists()) {
      await captioned.delete();
      await subtitle.delete();
      return current;
    }

    final dir = await _vaultDirectory();
    final safe = original.hcvId.replaceAll(RegExp(r'[^A-Z0-9-]'), '');
    final encryptedCaptioned = File(
      p.join(
        dir.path,
        '$safe.${captionedHash.substring(0, 16)}.captioned.enc',
      ),
    );
    final encryptedSubtitle = File(
      p.join(
        dir.path,
        '$safe.${subtitleHash.substring(0, 16)}.subtitle.enc',
      ),
    );

    for (final target in [encryptedCaptioned, encryptedSubtitle]) {
      if (await target.exists()) await target.delete();
    }

    final oldCaptionedPath = current.encryptedCaptionedMediaPath;
    final oldSubtitlePath = current.encryptedSubtitlePath;
    var committed = false;
    try {
      await _encryptFile(
        source: captioned,
        destination: encryptedCaptioned,
        sha256Hex: captionedHash,
        mimeType: 'video/mp4',
        originalName: p.basename(captioned.path),
      );
      await _encryptFile(
        source: subtitle,
        destination: encryptedSubtitle,
        sha256Hex: subtitleHash,
        mimeType: 'application/x-subrip',
        originalName: p.basename(subtitle.path),
      );

      late HCVSecureOriginalRecord updated;
      await _withIndexLock(() async {
        final records = await _loadIndex();
        final index =
            records.indexWhere((item) => item.hcvId == original.hcvId);
        if (index < 0) throw StateError('SECURE_VAULT_RECORD_NOT_FOUND');
        final latest = records[index];
        if (latest.ownerAccountSubjectHash !=
            await _currentAccountSubjectHash()) {
          throw StateError('SECURE_VAULT_ACCOUNT_MISMATCH');
        }

        updated = HCVSecureOriginalRecord(
          hcvId: latest.hcvId,
          ownerCreatorId: latest.ownerCreatorId,
          ownerAccountSubjectHash: latest.ownerAccountSubjectHash,
          mediaType: latest.mediaType,
          originalName: latest.originalName,
          mediaSha256: latest.mediaSha256,
          mediaSize: latest.mediaSize,
          encryptedMediaPath: latest.encryptedMediaPath,
          hcvpackSha256: latest.hcvpackSha256,
          hcvpackSize: latest.hcvpackSize,
          encryptedHcvpackPath: latest.encryptedHcvpackPath,
          certificatePath: latest.certificatePath,
          createdAt: latest.createdAt,
          publicationId: latest.publicationId,
          referenceUrl: latest.referenceUrl,
          referenceSha256: latest.referenceSha256,
          publishedAt: latest.publishedAt,
          captionedMediaSha256: captionedHash,
          captionedMediaSize: captionedSize,
          encryptedCaptionedMediaPath: encryptedCaptioned.path,
          subtitleSha256: subtitleHash,
          subtitleSize: subtitleSize,
          encryptedSubtitlePath: encryptedSubtitle.path,
        );
        records[index] = updated;
        await _saveIndex(records);
      });
      committed = true;

      for (final oldPath in [oldCaptionedPath, oldSubtitlePath]) {
        if (oldPath == null ||
            oldPath == encryptedCaptioned.path ||
            oldPath == encryptedSubtitle.path) {
          continue;
        }
        try {
          final old = File(oldPath);
          if (await old.exists()) await old.delete();
        } catch (_) {}
      }

      await captioned.delete();
      await subtitle.delete();
      return updated;
    } finally {
      if (!committed) {
        for (final target in [encryptedCaptioned, encryptedSubtitle]) {
          try {
            if (await target.exists()) await target.delete();
          } catch (_) {}
        }
      }
    }
  }

  Future<File> materializeCaptionedVideo(
    HCVSecureOriginalRecord record, {
    String purpose = 'subtitle-reference',
  }) async {
    if (!record.hasSubtitleDerivative ||
        record.encryptedCaptionedMediaPath == null ||
        record.captionedMediaSha256 == null) {
      throw StateError('SECURE_VAULT_SUBTITLE_DERIVATION_MISSING');
    }
    if (record.ownerCreatorId != await _currentCreatorId() ||
        record.ownerAccountSubjectHash != await _currentAccountSubjectHash()) {
      throw StateError('SECURE_VAULT_ACCOUNT_MISMATCH');
    }
    final tempRoot = await getTemporaryDirectory();
    final dir =
        Directory(p.join(tempRoot.path, 'sigillum_secure_materialized'));
    if (!await dir.exists()) await dir.create(recursive: true);
    final target = File(
      p.join(
        dir.path,
        '${record.hcvId}_$purpose_${DateTime.now().microsecondsSinceEpoch}.mp4',
      ),
    );
    await _decryptFile(
      encrypted: File(record.encryptedCaptionedMediaPath!),
      destination: target,
      expectedSha256: record.captionedMediaSha256!,
    );
    return target;
  }

  Future<File> materializeSubtitle(
    HCVSecureOriginalRecord record, {
    String purpose = 'subtitle-export',
  }) async {
    if (!record.hasSubtitleDerivative ||
        record.encryptedSubtitlePath == null ||
        record.subtitleSha256 == null) {
      throw StateError('SECURE_VAULT_SUBTITLE_DERIVATION_MISSING');
    }
    if (record.ownerCreatorId != await _currentCreatorId() ||
        record.ownerAccountSubjectHash != await _currentAccountSubjectHash()) {
      throw StateError('SECURE_VAULT_ACCOUNT_MISMATCH');
    }
    final tempRoot = await getTemporaryDirectory();
    final dir =
        Directory(p.join(tempRoot.path, 'sigillum_secure_materialized'));
    if (!await dir.exists()) await dir.create(recursive: true);
    final target = File(
      p.join(
        dir.path,
        '${record.hcvId}_$purpose_${DateTime.now().microsecondsSinceEpoch}.srt',
      ),
    );
    await _decryptFile(
      encrypted: File(record.encryptedSubtitlePath!),
      destination: target,
      expectedSha256: record.subtitleSha256!,
    );
    return target;
  }

  Future<void> markSubtitleReference({
    required String hcvId,
    required String publicationId,
    required String referenceUrl,
    required String referenceSha256,
    required String captionedMediaSha256,
    required String subtitleSha256,
  }) async {
    if (!_shaPattern.hasMatch(referenceSha256) ||
        !_shaPattern.hasMatch(captionedMediaSha256) ||
        !_shaPattern.hasMatch(subtitleSha256)) {
      throw ArgumentError('SECURE_VAULT_SUBTITLE_REFERENCE_HASH_INVALID');
    }

    await _withIndexLock(() async {
      final records = await _loadIndex();
      final index = records.indexWhere((item) => item.hcvId == hcvId);
      if (index < 0) throw StateError('SECURE_VAULT_RECORD_NOT_FOUND');
      final current = records[index];
      if (current.ownerAccountSubjectHash !=
              await _currentAccountSubjectHash() ||
          current.captionedMediaSha256 != captionedMediaSha256 ||
          current.subtitleSha256 != subtitleSha256) {
        throw StateError('SECURE_VAULT_SUBTITLE_REFERENCE_BINDING_MISMATCH');
      }

      records[index] = HCVSecureOriginalRecord(
        hcvId: current.hcvId,
        ownerCreatorId: current.ownerCreatorId,
        ownerAccountSubjectHash: current.ownerAccountSubjectHash,
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
        publicationId: current.publicationId,
        referenceUrl: current.referenceUrl,
        referenceSha256: current.referenceSha256,
        publishedAt: current.publishedAt,
        captionedMediaSha256: current.captionedMediaSha256,
        captionedMediaSize: current.captionedMediaSize,
        encryptedCaptionedMediaPath: current.encryptedCaptionedMediaPath,
        subtitleSha256: current.subtitleSha256,
        subtitleSize: current.subtitleSize,
        encryptedSubtitlePath: current.encryptedSubtitlePath,
        subtitlePublicationId: publicationId,
        subtitleReferenceUrl: referenceUrl,
        subtitleReferenceSha256: referenceSha256,
        subtitlePublishedAt: DateTime.now().toUtc(),
      );
      await _saveIndex(records);
    });
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
      if (current.ownerAccountSubjectHash !=
          await _currentAccountSubjectHash()) {
        throw StateError('SECURE_VAULT_ACCOUNT_MISMATCH');
      }
      records[index] = HCVSecureOriginalRecord(
        hcvId: current.hcvId,
        ownerCreatorId: current.ownerCreatorId,
        ownerAccountSubjectHash: current.ownerAccountSubjectHash,
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
        captionedMediaSha256: current.captionedMediaSha256,
        captionedMediaSize: current.captionedMediaSize,
        encryptedCaptionedMediaPath: current.encryptedCaptionedMediaPath,
        subtitleSha256: current.subtitleSha256,
        subtitleSize: current.subtitleSize,
        encryptedSubtitlePath: current.encryptedSubtitlePath,
        subtitlePublicationId: current.subtitlePublicationId,
        subtitleReferenceUrl: current.subtitleReferenceUrl,
        subtitleReferenceSha256: current.subtitleReferenceSha256,
        subtitlePublishedAt: current.subtitlePublishedAt,
      );
      await _saveIndex(records);
    });
  }

  Future<void> clearReference(String hcvId) async {
    await _withIndexLock(() async {
      final records = await _loadIndex();
      final index = records.indexWhere((item) => item.hcvId == hcvId);
      if (index < 0) throw StateError('SECURE_VAULT_RECORD_NOT_FOUND');
      final current = records[index];
      if (current.ownerAccountSubjectHash !=
          await _currentAccountSubjectHash()) {
        throw StateError('SECURE_VAULT_ACCOUNT_MISMATCH');
      }
      records[index] = HCVSecureOriginalRecord(
        hcvId: current.hcvId,
        ownerCreatorId: current.ownerCreatorId,
        ownerAccountSubjectHash: current.ownerAccountSubjectHash,
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
        captionedMediaSha256: current.captionedMediaSha256,
        captionedMediaSize: current.captionedMediaSize,
        encryptedCaptionedMediaPath: current.encryptedCaptionedMediaPath,
        subtitleSha256: current.subtitleSha256,
        subtitleSize: current.subtitleSize,
        encryptedSubtitlePath: current.encryptedSubtitlePath,
        subtitlePublicationId: current.subtitlePublicationId,
        subtitleReferenceUrl: current.subtitleReferenceUrl,
        subtitleReferenceSha256: current.subtitleReferenceSha256,
        subtitlePublishedAt: current.subtitlePublishedAt,
      );
      await _saveIndex(records);
    });
  }

  Future<void> purgeMaterializedPlaintext() async {
    try {
      final tempRoot = await getTemporaryDirectory();
      for (final name in const [
        'sigillum_secure_materialized',
        'sigillum_secure_previews',
      ]) {
        final dir = Directory(p.join(tempRoot.path, name));
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      }
    } catch (_) {}
  }

  Future<void> deleteMaterialized(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  Future<void> wipeAccountVault(String accountId) async {
    final ownerSubject = _accountSubjectHash(accountId);
    final removedIds = <String>[];
    final becameEmpty = await _withIndexLock(() async {
      final records = await _loadIndex();
      final owned = records
          .where((item) => item.ownerAccountSubjectHash == ownerSubject)
          .toList();
      if (owned.isEmpty) return false;
      for (final item in owned) {
        removedIds.add(item.hcvId);
        for (final path in [
          item.encryptedMediaPath,
          item.encryptedHcvpackPath,
          item.certificatePath,
          if (item.encryptedCaptionedMediaPath != null)
            item.encryptedCaptionedMediaPath!,
          if (item.encryptedSubtitlePath != null) item.encryptedSubtitlePath!,
        ]) {
          try {
            final file = File(path);
            if (await file.exists()) await file.delete();
          } catch (_) {}
        }
      }
      records.removeWhere(
        (item) => item.ownerAccountSubjectHash == ownerSubject,
      );
      if (records.isEmpty) {
        final dir = await _vaultDirectory();
        if (await dir.exists()) await dir.delete(recursive: true);
        return true;
      }
      await _saveIndex(records);
      return false;
    });
    if (becameEmpty) {
      await HCVSecureStore.delete(_masterKeyStoreKey);
    }
    if (removedIds.isEmpty) return;
    try {
      final tempRoot = await getTemporaryDirectory();
      final materialized =
          Directory(p.join(tempRoot.path, 'sigillum_secure_materialized'));
      if (!await materialized.exists()) return;
      await for (final entity in materialized.list()) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        if (removedIds.any((hcvId) => name.startsWith(hcvId))) {
          try {
            await entity.delete();
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  Future<void> wipeCreatorVault(String creatorId) async {
    final owner = creatorId.trim();
    if (owner.isEmpty) {
      throw ArgumentError('SECURE_VAULT_CREATOR_ID_UNAVAILABLE');
    }

    final removedIds = <String>[];
    final becameEmpty = await _withIndexLock(() async {
      final records = await _loadIndex();
      final owned =
          records.where((item) => item.ownerCreatorId == owner).toList();
      if (owned.isEmpty) return false;

      for (final item in owned) {
        removedIds.add(item.hcvId);
        for (final path in [
          item.encryptedMediaPath,
          item.encryptedHcvpackPath,
          item.certificatePath,
        ]) {
          try {
            final file = File(path);
            if (await file.exists()) await file.delete();
          } catch (_) {}
        }
      }

      records.removeWhere((item) => item.ownerCreatorId == owner);
      if (records.isEmpty) {
        final dir = await _vaultDirectory();
        if (await dir.exists()) await dir.delete(recursive: true);
        return true;
      }

      await _saveIndex(records);
      return false;
    });

    if (becameEmpty) {
      await HCVSecureStore.delete(_masterKeyStoreKey);
    }

    if (removedIds.isEmpty) return;
    try {
      final tempRoot = await getTemporaryDirectory();
      final materialized =
          Directory(p.join(tempRoot.path, 'sigillum_secure_materialized'));
      if (!await materialized.exists()) return;
      await for (final entity in materialized.list()) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        if (removedIds.any((hcvId) => name.startsWith(hcvId))) {
          try {
            await entity.delete();
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  Future<void> wipeLocalVault() async {
    await _withIndexLock(() async {
      final dir = await _vaultDirectory();
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      await HCVSecureStore.delete(_masterKeyStoreKey);
    });

    try {
      final tempRoot = await getTemporaryDirectory();
      final materialized =
          Directory(p.join(tempRoot.path, 'sigillum_secure_materialized'));
      if (await materialized.exists()) {
        await materialized.delete(recursive: true);
      }
    } catch (_) {}
  }

  String _photoMime(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    return 'image/jpeg';
  }
}
