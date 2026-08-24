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

for token in [
    "_v('registryNotFound')",
    "_v('registryUnavailable')",
    "_v('verificationIncomplete')",
]:
    if token not in source:
        raise RuntimeError(f'localized Registry result token missing: {token}')

path.write_text(source, encoding='utf-8')
print('Registry public result copy fully localized; raw internal Italian status hidden')
