import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_text_integrity.dart';

Map<String, dynamic> certificateFor(String text) {
  final snapshot = HCVTextIntegrity.fromText(text);
  return {
    'meta': {'hcvId': 'HCV-0123456789ABCDEF'},
    'content': {
      'type': 'text',
      'hash': snapshot.exactTextSha256,
    },
    'claims': {
      'textIntegrity': snapshot.toJson(),
    },
  };
}

void main() {
  test('exact published text matches the signed exact hash', () {
    const original = 'Prima riga.\nSeconda riga!';
    final published = HCVTextIntegrity.buildSocialText(
      original,
      'HCV-0123456789ABCDEF',
    );
    final result = HCVTextIntegrity.comparePublishedText(
      publishedText: published,
      certificate: certificateFor(original),
    );
    expect(result.kind, HCVTextMatchKind.exact);
  });

  test('social whitespace changes remain formatting-only', () {
    const original = 'Prima riga.\n\nSeconda   riga!';
    const published =
        'Prima riga. Seconda riga!\n\n🔏 SIGILLUM HCV-0123456789ABCDEF';
    final result = HCVTextIntegrity.comparePublishedText(
      publishedText: published,
      certificate: certificateFor(original),
    );
    expect(result.kind, HCVTextMatchKind.formattingOnly);
  });

  test('word or punctuation changes are rejected', () {
    const original = 'Questa frase è originale.';
    const published =
        'Questa frase è modificata!\n\n🔏 SIGILLUM HCV-0123456789ABCDEF';
    final result = HCVTextIntegrity.comparePublishedText(
      publishedText: published,
      certificate: certificateFor(original),
    );
    expect(result.kind, HCVTextMatchKind.modified);
  });

  test('new and legacy markers are removed only from the end', () {
    expect(
      HCVTextIntegrity.stripSigillumMarker(
        'Testo\n\n🔏 SIGILLUM HCV-0123456789ABCDEF',
      ),
      'Testo',
    );
    expect(
      HCVTextIntegrity.stripSigillumMarker(
        'Testo\n\nHCV VERIFIED\nID: HCV-0123456789ABCDEF\nVerify with SIGILLUM',
      ),
      'Testo',
    );
  });

  test('text HCVPACK contains one original and one certificate', () async {
    final temp = await Directory.systemTemp.createTemp('hcv_text_package_test');
    addTearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });
    final textFile = File('${temp.path}/original-source.txt');
    final hcvFile = File('${temp.path}/certificate-source.hcv');
    await textFile.writeAsString('Contenuto certificato', encoding: utf8);
    await hcvFile.writeAsString('{"certificate":true}', encoding: utf8);

    final packagePath = await HCVTextPackage.create(
      textPath: textFile.path,
      hcvPath: hcvFile.path,
      hcvId: 'HCV-0123456789ABCDEF',
      outputDirectory: temp,
    );
    final archive = ZipDecoder().decodeBytes(await File(packagePath).readAsBytes());
    final names = archive.files.map((entry) => entry.name).toSet();
    expect(names, containsAll({'original.txt', 'certificate.hcv', 'meta.json'}));

    final read = await HCVTextPackage.read(packagePath);
    expect(read.originalText, 'Contenuto certificato');
    expect(jsonDecode(read.certificateRaw), {'certificate': true});
  });
}
