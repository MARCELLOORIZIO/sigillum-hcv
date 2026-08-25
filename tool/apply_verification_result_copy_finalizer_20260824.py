from pathlib import Path


def replace_balanced_function(source: str, signature: str, replacement: str) -> str:
    start = source.find(signature)
    if start < 0:
        raise RuntimeError(f'Function signature not found: {signature}')
    brace = source.find('{', start)
    if brace < 0:
        raise RuntimeError(f'Function body not found: {signature}')
    depth = 0
    end = None
    for index in range(brace, len(source)):
        char = source[index]
        if char == '{':
            depth += 1
        elif char == '}':
            depth -= 1
            if depth == 0:
                end = index + 1
                break
    if end is None:
        raise RuntimeError(f'Unbalanced function body: {signature}')
    return source[:start] + replacement.rstrip() + source[end:]


path = Path('lib/registry_verify_page.dart')
source = path.read_text(encoding='utf-8')

replacement = r'''  String get _publicResultDetail {
    if (_isForensicResult) return _v('forensicOkDetail');
    if (_isSocialResult) return _v('socialOkDetail');
    final value = result ?? '';
    if (value.contains('REGISTRY NOT FOUND')) return _v('registryNotFound');
    if (value.contains('REGISTRY UNAVAILABLE') ||
        value.contains('REGISTRY ERROR')) {
      return _v('registryUnavailable');
    }
    if (_isInvalidResult || _isMediaNotVerified) return _v('notVerified');
    return _v('verificationIncomplete');
  }'''

source = replace_balanced_function(
    source,
    '  String get _publicResultDetail',
    replacement,
)

if 'return status;' in source[source.find('  String get _publicResultDetail'):source.find('  @override\n  Widget build', source.find('  String get _publicResultDetail'))]:
    raise RuntimeError('raw internal status still exposed by public Registry result')

# The helper below the Registry action was still a const Italian literal.
# Move it into the same four-language verification catalog used by the rest of
# the public Registry UI. At the same time, make derived-content copy neutral:
# a compatible fingerprint proves derivation compatibility, but it cannot by
# itself determine whether the byte difference came from subtitles,
# recompression, renaming or another edit.
copy_path = Path('lib/verification_ui_copy.dart')
copy_source = copy_path.read_text(encoding='utf-8')

copy_replacements = [
    (
        "      'derivedDetail': 'File ricompresso o modificato, ma compatibile con il certificato.',",
        "      'derivedDetail': 'Hash diverso dall’originale certificato, ma HCV-ID e fingerprint restano compatibili.',",
    ),
    (
        "      'derivedDerivationDetail': 'Il file è una copia o versione ricompressa compatibile.',",
        "      'derivedDerivationDetail': 'Versione derivata compatibile; la verifica non distingue da sola tra sottotitoli, ricompressione o altre modifiche.',",
    ),
    (
        "      'socialOkDetail': 'Il file è stato ricompresso o rinominato, ma resta collegato al certificato SIGILLUM.',",
        "      'socialOkDetail': 'Il file è diverso dall’originale certificato, ma resta collegato al certificato SIGILLUM tramite HCV-ID e fingerprint.',",
    ),
    (
        "      'derivedDetail': 'The file was recompressed or changed but remains compatible with the certificate.',",
        "      'derivedDetail': 'The hash differs from the certified original, but HCV-ID and fingerprint remain compatible.',",
    ),
    (
        "      'derivedDerivationDetail': 'The file is a compatible copy or recompressed version.',",
        "      'derivedDerivationDetail': 'Compatible derived version; verification alone does not distinguish subtitles, recompression, or other edits.',",
    ),
    (
        "      'socialOkDetail': 'The file was recompressed or renamed but remains linked to the SIGILLUM certificate.',",
        "      'socialOkDetail': 'The file differs from the certified original but remains linked to the SIGILLUM certificate through its HCV-ID and fingerprint.',",
    ),
    (
        "      'derivedDetail': 'El archivo fue recomprimido o modificado, pero sigue siendo compatible con el certificado.',",
        "      'derivedDetail': 'El hash difiere del original certificado, pero el HCV-ID y la huella siguen siendo compatibles.',",
    ),
    (
        "      'derivedDerivationDetail': 'El archivo es una copia o versión recomprimida compatible.',",
        "      'derivedDerivationDetail': 'Versión derivada compatible; la verificación por sí sola no distingue entre subtítulos, recompresión u otras modificaciones.',",
    ),
    (
        "      'socialOkDetail': 'El archivo fue recomprimido o renombrado, pero sigue vinculado al certificado SIGILLUM.',",
        "      'socialOkDetail': 'El archivo difiere del original certificado, pero sigue vinculado al certificado SIGILLUM mediante el HCV-ID y la huella.',",
    ),
    (
        "      'derivedDetail': 'Файл был перекодирован или изменён, но совместим с сертификатом.',",
        "      'derivedDetail': 'Хэш отличается от сертифицированного оригинала, но HCV-ID и отпечаток остаются совместимыми.',",
    ),
    (
        "      'derivedDerivationDetail': 'Файл является совместимой копией или перекодированной версией.',",
        "      'derivedDerivationDetail': 'Совместимая производная версия; сама проверка не различает субтитры, перекодирование и другие изменения.',",
    ),
    (
        "      'socialOkDetail': 'Файл был перекодирован или переименован, но остаётся связан с сертификатом SIGILLUM.',",
        "      'socialOkDetail': 'Файл отличается от сертифицированного оригинала, но остаётся связан с сертификатом SIGILLUM через HCV-ID и отпечаток.',",
    ),
]
for old, new in copy_replacements:
    if old in copy_source:
        copy_source = copy_source.replace(old, new, 1)
    elif new not in copy_source:
        raise RuntimeError(f'verification derived-copy anchor missing: {old}')

helper_insertions = [
    (
        "      'verificationIncomplete': 'Verifica non completata.',\n",
        "      'verificationIncomplete': 'Verifica non completata.',\n"
        "      'registryHelper': 'Il certificato viene recuperato automaticamente dal Registry HCV. Seleziona il file che vuoi verificare.',\n",
    ),
    (
        "      'verificationIncomplete': 'Verification was not completed.',\n",
        "      'verificationIncomplete': 'Verification was not completed.',\n"
        "      'registryHelper': 'The certificate is retrieved automatically from the HCV Registry. Select the file you want to verify.',\n",
    ),
    (
        "      'verificationIncomplete': 'No se completó la verificación.',\n",
        "      'verificationIncomplete': 'No se completó la verificación.',\n"
        "      'registryHelper': 'El certificado se recupera automáticamente del Registry HCV. Selecciona el archivo que quieres verificar.',\n",
    ),
    (
        "      'verificationIncomplete': 'Проверка не завершена.',\n",
        "      'verificationIncomplete': 'Проверка не завершена.',\n"
        "      'registryHelper': 'Сертификат автоматически загружается из Registry HCV. Выберите файл, который хотите проверить.',\n",
    ),
]
for old, new in helper_insertions:
    if "'registryHelper':" in copy_source and old not in copy_source:
        continue
    if old in copy_source:
        copy_source = copy_source.replace(old, new, 1)
    elif new not in copy_source:
        raise RuntimeError(f'Registry helper localization anchor missing: {old}')

for language_token in [
    "'it': {",
    "'en': {",
    "'es': {",
    "'ru': {",
]:
    if language_token not in copy_source:
        raise RuntimeError(f'verification language catalog missing: {language_token}')
if copy_source.count("'registryHelper':") != 4:
    raise RuntimeError('Registry helper must exist in all four language catalogs')

copy_path.write_text(copy_source, encoding='utf-8')

old_helper = """              const Text(
                'Il certificato viene recuperato automaticamente dal Registry HCV. Devi selezionare SOLO il file originale.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),"""
new_helper = """              Text(
                _v('registryHelper'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),"""
if old_helper in source:
    source = source.replace(old_helper, new_helper, 1)
elif "_v('registryHelper')" not in source:
    raise RuntimeError('hardcoded Registry helper anchor missing')

if 'Il certificato viene recuperato automaticamente dal Registry HCV. Devi selezionare SOLO il file originale.' in source:
    raise RuntimeError('hardcoded Italian Registry helper survived localization')

for token in [
    "_v('registryNotFound')",
    "_v('registryUnavailable')",
    "_v('verificationIncomplete')",
    "_v('registryHelper')",
]:
    if token not in source:
        raise RuntimeError(f'localized Registry result token missing: {token}')

path.write_text(source, encoding='utf-8')
print('Registry public result copy localized; derived-content wording made evidence-neutral')
