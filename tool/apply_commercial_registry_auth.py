from pathlib import Path

path = Path('lib/hcv_registry_service.dart')
source = path.read_text(encoding='utf-8')

import_anchor = "import 'hcv_keystore_signer.dart';\n"
import_value = "import 'hcv_keystore_signer.dart';\nimport 'hcv_secure_store.dart';\n"
if "import 'hcv_secure_store.dart';" not in source:
    if import_anchor not in source:
        raise RuntimeError('Registry auth import anchor not found')
    source = source.replace(import_anchor, import_value, 1)

header_anchor = "      req.headers.contentType = ContentType.json;\n\n      req.write(jsonEncode({"
header_value = "      req.headers.contentType = ContentType.json;\n      final sessionToken = await HCVSecureStore.read('sigillum.auth.session.v1');\n      if (sessionToken != null && sessionToken.isNotEmpty) {\n        req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $sessionToken');\n      }\n\n      req.write(jsonEncode({"
if "final sessionToken = await HCVSecureStore.read('sigillum.auth.session.v1');" not in source:
    count = source.count(header_anchor)
    if count != 1:
        raise RuntimeError(f'Registry auth upload anchor expected once, found {count}')
    source = source.replace(header_anchor, header_value, 1)

path.write_text(source, encoding='utf-8')
print('Commercial Registry authorization applied to certificate POST only')
