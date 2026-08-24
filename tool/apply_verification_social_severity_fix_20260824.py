from pathlib import Path

path = Path('lib/registry_verify_page.dart')
source = path.read_text(encoding='utf-8')

old = """    if (_isDisplayNonConclusive || _isRegistryWarningResult) {
      return Colors.orange;
    }
    if (isVerified) return Colors.green;
"""
new = """    if (_isDisplayNonConclusive || _isRegistryWarningResult || _isSocialResult) {
      return Colors.orange;
    }
    if (_isForensicResult) return Colors.green;
    if (isVerified) return Colors.green;
"""

if new not in source:
    if old not in source:
        raise RuntimeError('overall verification severity anchor missing')
    source = source.replace(old, new, 1)

path.write_text(source, encoding='utf-8')
print('Compatible derivative verification uses intermediate orange severity')
