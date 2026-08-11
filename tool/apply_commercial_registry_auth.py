from pathlib import Path

path = Path('lib/hcv_registry_service.dart')
source = path.read_text(encoding='utf-8')

import_anchor = "import 'hcv_keystore_signer.dart';\n"
import_value = "import 'hcv_keystore_signer.dart';\nimport 'hcv_secure_store.dart';\n"
if "import 'hcv_secure_store.dart';" not in source:
    if import_anchor not in source:
        raise RuntimeError('Registry auth import anchor not found')
    source = source.replace(import_anchor, import_value, 1)

old_base = """  const HCVRegistryService({
    this.baseUrl = 'https://hcv-registry-server.onrender.com',
  });
"""
new_base = """  const HCVRegistryService({
    this.baseUrl = const String.fromEnvironment(
      'SIGILLUM_API_BASE_URL',
      defaultValue: 'https://hcv-registry-server.onrender.com',
    ),
  });
"""
if old_base in source:
    source = source.replace(old_base, new_base, 1)
elif "'SIGILLUM_API_BASE_URL'" not in source:
    raise RuntimeError('Registry base URL anchor not found')

header_anchor = "      req.headers.contentType = ContentType.json;\n\n      req.write(jsonEncode({"
header_value = "      req.headers.contentType = ContentType.json;\n      final sessionToken = await HCVSecureStore.read('sigillum.auth.session.v1');\n      if (sessionToken != null && sessionToken.isNotEmpty) {\n        req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $sessionToken');\n      }\n\n      req.write(jsonEncode({"
if "final sessionToken = await HCVSecureStore.read('sigillum.auth.session.v1');" not in source:
    count = source.count(header_anchor)
    if count != 1:
        raise RuntimeError(f'Registry auth upload anchor expected once, found {count}')
    source = source.replace(header_anchor, header_value, 1)

required = [
    "'SIGILLUM_API_BASE_URL'",
    "HCVSecureStore.read('sigillum.auth.session.v1')",
    "HttpHeaders.authorizationHeader",
]
for token in required:
    if token not in source:
        raise RuntimeError(f'commercial Registry transport token missing: {token}')

path.write_text(source, encoding='utf-8')
print('Commercial Registry authorization and configurable production API applied to transport only')
