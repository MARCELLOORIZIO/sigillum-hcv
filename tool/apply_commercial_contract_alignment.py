from pathlib import Path

path = Path('lib/hcv_registry_service.dart')
source = path.read_text(encoding='utf-8')

constant = "  static const _sessionTokenKey = 'sigillum.auth.session.v1';\n"
if constant in source:
    source = source.replace(constant, '', 1)

old = "      final sessionToken = await HCVSecureStore.read(_sessionTokenKey);\n"
new = "      final sessionToken =\n          await HCVSecureStore.read('sigillum.auth.session.v1');\n"
if old not in source:
    raise RuntimeError('Registry session-token read anchor missing')
source = source.replace(old, new, 1)

if "HCVSecureStore.read('sigillum.auth.session.v1')" not in source:
    raise RuntimeError('Registry authenticated session literal missing')
if "'Bearer $sessionToken'" not in source:
    raise RuntimeError('Registry bearer token missing')

path.write_text(source, encoding='utf-8')
print('Registry authentication contract aligned')
