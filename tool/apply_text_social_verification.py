from pathlib import Path

path = Path('lib/text_cert_page.dart')
source = path.read_text(encoding='utf-8')
original = source


def replace_once(old: str, new: str, label: str) -> None:
    global source
    count = source.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected 1 occurrence, found {count}')
    source = source.replace(old, new, 1)

replace_once(
    "import 'hcv_registry_service.dart';\nimport 'sigillum_localization.dart';",
    "import 'hcv_registry_service.dart';\nimport 'hcv_text_integrity.dart';\nimport 'text_social_verify_page.dart';\nimport 'sigillum_localization.dart';",
    'imports',
)

replace_once(
    "  String? textPath;\n  String? hcvId;",
    "  String? textPath;\n  String? packagePath;\n  String? hcvId;",
    'package field',
)

old_output = """  Future<Directory> _outputDirectory() async {
    final outputDir = Platform.isAndroid
        ? Directory('/storage/emulated/0/Download')
        : Directory.systemTemp;

    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }

    return outputDir;
  }
"""
new_output = """  Future<Directory> _outputDirectory() async {
    return HCVTextArtifactStore.outputDirectory();
  }
"""
replace_once(old_output, new_output, 'persistent output directory')

replace_once(
    "        textPath = null;\n        hcvId = null;",
    "        textPath = null;\n        packagePath = null;\n        hcvId = null;",
    'creation reset',
)

replace_once(
    "      final textHash = sha256.convert(textBytes).toString();\n\n      engine.setContent(",
    "      final textHash = sha256.convert(textBytes).toString();\n      final textIntegrity = HCVTextIntegrity.fromText(text);\n      engine.setClaims({\n        'textIntegrity': textIntegrity.toJson(),\n      });\n\n      engine.setContent(",
    'signed integrity claims',
)

replace_once(
    """      setState(() {
        loading = false;
        hcvPath = finalHcvPath;
        textPath = finalTextPath;
        hcvId = detectedId;
""",
    """      String? finalPackagePath;
      final packageId = detectedId ?? engine.hcvId;
      try {
        finalPackagePath = await HCVTextPackage.create(
          textPath: finalTextPath,
          hcvPath: finalHcvPath,
          hcvId: packageId,
        );
      } catch (_) {}

      setState(() {
        loading = false;
        hcvPath = finalHcvPath;
        textPath = finalTextPath;
        packagePath = finalPackagePath;
        hcvId = packageId;
""",
    'package creation',
)

old_social = """    final socialText = hcvId == null
        ? originalText
        : '$originalText\\n\\nHCV VERIFIED\\nID: $hcvId\\nVerify with SIGILLUM';
"""
new_social = """    final socialText = hcvId == null
        ? originalText
        : HCVTextIntegrity.buildSocialText(originalText, hcvId!);
"""
if source.count(old_social) != 2:
    raise SystemExit(f'social text builders: expected 2 occurrences, found {source.count(old_social)}')
source = source.replace(old_social, new_social)

replace_once(
    """  Future<void> shareTextFileAndCertificate() async {
    if (textPath == null || hcvPath == null) return;

    final shareText = hcvId == null
        ? 'Testo verificato SIGILLUM'
        : 'Testo verificato SIGILLUM\\nID: $hcvId\\nVerify with SIGILLUM';

    await Share.shareXFiles(
      [XFile(textPath!), XFile(hcvPath!)],
      text: shareText,
      sharePositionOrigin: const Rect.fromLTWH(0, 0, 1, 1),
    );
  }
""",
    """  Future<void> shareTextFileAndCertificate() async {
    if (textPath == null || hcvPath == null) return;

    final shareText = hcvId == null
        ? 'Testo verificato SIGILLUM'
        : 'Testo verificato SIGILLUM\\n$hcvId';

    await Share.shareXFiles(
      [XFile(textPath!), XFile(hcvPath!)],
      text: shareText,
      sharePositionOrigin: const Rect.fromLTWH(0, 0, 1, 1),
    );
  }

  Future<void> shareTextPackage() async {
    if (packagePath == null) return;
    await Share.shareXFiles(
      [XFile(packagePath!)],
      text: hcvId == null ? 'SIGILLUM HCVPACK testo' : 'SIGILLUM $hcvId',
      sharePositionOrigin: const Rect.fromLTWH(0, 0, 1, 1),
    );
  }

  Future<void> openPublishedTextVerification() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TextSocialVerifyPage(
          languageCode: widget.languageCode,
          initialText: result == null ? null : controller.text,
        ),
      ),
    );
  }
""",
    'share and verification methods',
)

replace_once(
    """        if (textPath != null && hcvPath != null)
          SizedBox(
            width: 300,
            child: ElevatedButton.icon(
              onPressed: shareTextFileAndCertificate,
              icon: const Icon(Icons.attach_file),
              label: Text(_t('shareTxtCertificate')),
            ),
          ),
""",
    """        if (textPath != null && hcvPath != null)
          SizedBox(
            width: 300,
            child: ElevatedButton.icon(
              onPressed: shareTextFileAndCertificate,
              icon: const Icon(Icons.attach_file),
              label: Text(_t('shareTxtCertificate')),
            ),
          ),
        if (packagePath != null) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: 300,
            child: ElevatedButton.icon(
              onPressed: shareTextPackage,
              icon: const Icon(Icons.inventory_2_outlined),
              label: Text(
                widget.languageCode.toLowerCase().startsWith('it')
                    ? 'CONDIVIDI HCVPACK TESTO'
                    : 'SHARE TEXT HCVPACK',
              ),
            ),
          ),
        ],
""",
    'package button',
)

replace_once(
    """            if (hcvPath != null) ...[
              const SizedBox(height: 8),
              Text(
                '${_t('certificate')}:\\n$hcvPath',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11),
              ),
            ],
""",
    """            if (hcvPath != null) ...[
              const SizedBox(height: 8),
              Text(
                '${_t('certificate')}:\\n$hcvPath',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11),
              ),
            ],
            if (packagePath != null) ...[
              const SizedBox(height: 8),
              Text(
                'HCVPACK:\\n$packagePath',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11),
              ),
            ],
""",
    'created package card',
)

replace_once(
    "      textPath = null;\n      hcvId = null;",
    "      textPath = null;\n      packagePath = null;\n      hcvId = null;",
    'page reset',
)

replace_once(
    """              _createdFilesCard(),
              if (result != null) ...[
""",
    """              _createdFilesCard(),
              const SizedBox(height: 12),
              SizedBox(
                width: 300,
                child: OutlinedButton.icon(
                  onPressed: openPublishedTextVerification,
                  icon: const Icon(Icons.fact_check_outlined),
                  label: Text(
                    widget.languageCode.toLowerCase().startsWith('it')
                        ? 'VERIFICA TESTO PUBBLICATO'
                        : 'VERIFY PUBLISHED TEXT',
                  ),
                ),
              ),
              if (result != null) ...[
""",
    'verification navigation button',
)

if source == original:
    raise SystemExit('No changes applied')
path.write_text(source, encoding='utf-8')
print('Persistent text artifacts, HCVPACK and social verification integrated')
