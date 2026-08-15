from pathlib import Path

registry_path = Path('lib/hcv_registry_service.dart')
source = registry_path.read_text(encoding='utf-8')

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
      defaultValue: 'https://sigillum-registry-production.onrender.com',
    ),
  });
"""
if old_base in source:
    source = source.replace(old_base, new_base, 1)
elif "'SIGILLUM_API_BASE_URL'" not in source:
    raise RuntimeError('Registry base URL anchor not found')

# If an older configurable fallback is already present, force the commercial
# production fallback while still allowing the compile-time define to override it.
source = source.replace(
    "defaultValue: 'https://hcv-registry-server.onrender.com',",
    "defaultValue: 'https://sigillum-registry-production.onrender.com',",
)

header_anchor = "      req.headers.contentType = ContentType.json;\n\n      req.write(jsonEncode({"
header_value = "      req.headers.contentType = ContentType.json;\n      final sessionToken =\n          await HCVSecureStore.read('sigillum.auth.session.v1');\n      if (sessionToken == null || sessionToken.isEmpty) {\n        throw const HCVRegistryException(\n          HCVRegistryFailureKind.invalidResponse,\n          'Sessione Creator non disponibile per pubblicare nel Registry.',\n          statusCode: 401,\n        );\n      }\n      req.headers.set(\n        HttpHeaders.authorizationHeader,\n        'Bearer $sessionToken',\n      );\n\n      req.write(jsonEncode({"
if "HCVSecureStore.read('sigillum.auth.session.v1')" not in source:
    count = source.count(header_anchor)
    if count != 1:
        raise RuntimeError(f'Registry auth upload anchor expected once, found {count}')
    source = source.replace(header_anchor, header_value, 1)

required = [
    "'SIGILLUM_API_BASE_URL'",
    "'https://sigillum-registry-production.onrender.com'",
    "HCVSecureStore.read('sigillum.auth.session.v1')",
    "HttpHeaders.authorizationHeader",
    "'Bearer $sessionToken'",
]
for token in required:
    if token not in source:
        raise RuntimeError(f'commercial Registry transport token missing: {token}')

registry_path.write_text(source, encoding='utf-8')

# camera_page.dart is frozen in the commercial branch and must stay byte-for-byte
# identical to the validated capture baseline in Git. The production build step is
# allowed to remove only the historical iOS verifier bypass after the source guard.
camera_path = Path('lib/camera_page.dart')
camera = camera_path.read_text(encoding='utf-8')
old_ios_bypass = "    final ok = Platform.isIOS ? true : await verifier.verifyFile(hcv);\n"
verified_ios = "    final ok = await verifier.verifyFile(hcv);\n"
if old_ios_bypass in camera:
    if camera.count(old_ios_bypass) != 1:
        raise RuntimeError('iOS HCV verifier bypass anchor is not unique')
    camera = camera.replace(old_ios_bypass, verified_ios, 1)
elif verified_ios not in camera:
    raise RuntimeError('iOS HCV verifier enforcement anchor not found')

if 'Platform.isIOS ? true : await verifier.verifyFile(hcv)' in camera:
    raise RuntimeError('iOS HCV verification bypass remains in production build source')
if 'final ok = await verifier.verifyFile(hcv);' not in camera:
    raise RuntimeError('HCV verification is not enforced on iOS')

camera_path.write_text(camera, encoding='utf-8')
print('Commercial Registry authorization, production API and iOS HCV verification enforced')
