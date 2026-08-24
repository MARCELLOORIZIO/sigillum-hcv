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


path = Path('lib/hcv_registry_service.dart')
source = path.read_text(encoding='utf-8')

# The commercial migration moved Registry reads from the historical Render
# service to the integrated production API. Keep production as authoritative,
# but if it returns 404, try the historical read-only Registry once. This does
# not bypass upload authorization and does not change certificate validation.
legacy_marker = "  static const _legacyReadBaseUrl = 'https://hcv-registry-server.onrender.com';\n"
if legacy_marker not in source:
    anchor = "  static const _requestTimeout = Duration(seconds: 15);\n"
    if anchor not in source:
        raise RuntimeError('Registry timeout anchor missing')
    source = source.replace(anchor, anchor + legacy_marker, 1)

replacement = r'''  Future<Map<String, dynamic>> fetchCertificate(String hcvId) async {
    final cleaned = hcvId.trim().toUpperCase();

    if (!_hcvIdPattern.hasMatch(cleaned)) {
      throw const HCVRegistryException(
        HCVRegistryFailureKind.invalidResponse,
        'HCV-ID non valido: sono richiesti 16 caratteri esadecimali',
      );
    }

    HCVRegistryException? primaryNotFound;
    try {
      return await _fetchCertificateFromBase(baseUrl, cleaned);
    } on HCVRegistryException catch (e) {
      if (e.kind != HCVRegistryFailureKind.notFound ||
          baseUrl == _legacyReadBaseUrl) {
        rethrow;
      }
      primaryNotFound = e;
    }

    try {
      return await _fetchCertificateFromBase(_legacyReadBaseUrl, cleaned);
    } on HCVRegistryException {
      throw primaryNotFound!;
    }
  }

  Future<Map<String, dynamic>> _fetchCertificateFromBase(
    String registryBase,
    String cleaned,
  ) async {
    final client = HttpClient()..connectionTimeout = _requestTimeout;

    try {
      final uri = Uri.parse('$registryBase/api/certificate/$cleaned');
      final req = await client.getUrl(uri).timeout(_requestTimeout);
      final res = await req.close().timeout(_requestTimeout);
      final body = await utf8.decoder.bind(res).join().timeout(_requestTimeout);

      if (res.statusCode == 404) {
        throw const HCVRegistryException(
          HCVRegistryFailureKind.notFound,
          'Certificato non trovato nel Registry',
          statusCode: 404,
        );
      }

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw HCVRegistryException(
          res.statusCode >= 500
              ? HCVRegistryFailureKind.server
              : HCVRegistryFailureKind.invalidResponse,
          'Registry fetch error ${res.statusCode}: $body',
          statusCode: res.statusCode,
        );
      }

      late final dynamic decoded;
      try {
        decoded = jsonDecode(body);
      } catch (e) {
        throw HCVRegistryException(
          HCVRegistryFailureKind.invalidResponse,
          'Risposta registry non valida: $e',
        );
      }
      if (decoded is! Map<String, dynamic>) {
        throw const HCVRegistryException(
          HCVRegistryFailureKind.invalidResponse,
          'Risposta registry non valida',
        );
      }

      final certificateRaw = decoded['certificateRaw'];
      if (certificateRaw is String && certificateRaw.isNotEmpty) {
        final cert = jsonDecode(certificateRaw);
        if (cert is Map<String, dynamic>) {
          return cert;
        }
      }

      final certificate = decoded['certificate'];
      if (certificate is Map<String, dynamic>) {
        return certificate;
      }

      throw const HCVRegistryException(
        HCVRegistryFailureKind.invalidResponse,
        'Certificato assente nella risposta registry',
      );
    } on HCVRegistryException {
      rethrow;
    } on SocketException catch (e) {
      throw HCVRegistryException(
        HCVRegistryFailureKind.unavailable,
        'Registry non raggiungibile: ${e.message}',
      );
    } on HandshakeException catch (e) {
      throw HCVRegistryException(
        HCVRegistryFailureKind.unavailable,
        'Connessione sicura al Registry non disponibile: $e',
      );
    } on TimeoutException {
      throw const HCVRegistryException(
        HCVRegistryFailureKind.unavailable,
        'Tempo di risposta del Registry scaduto',
      );
    } on HttpException catch (e) {
      throw HCVRegistryException(
        HCVRegistryFailureKind.unavailable,
        'Errore di connessione al Registry: ${e.message}',
      );
    } finally {
      client.close(force: true);
    }
  }'''

if '_fetchCertificateFromBase(' not in source:
    source = replace_balanced_function(
        source,
        '  Future<Map<String, dynamic>> fetchCertificate(String hcvId)',
        replacement,
    )

required = [
    "_legacyReadBaseUrl = 'https://hcv-registry-server.onrender.com'",
    '_fetchCertificateFromBase(baseUrl, cleaned)',
    '_fetchCertificateFromBase(_legacyReadBaseUrl, cleaned)',
]
for token in required:
    if token not in source:
        raise RuntimeError(f'Registry compatibility token missing: {token}')

path.write_text(source, encoding='utf-8')
print('Registry production-first read with safe legacy 404 fallback applied')
