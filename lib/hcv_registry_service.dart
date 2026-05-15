import 'dart:convert';
import 'dart:io';

class HCVRegistryService {
  final String baseUrl;

  const HCVRegistryService({
    this.baseUrl = 'https://hcv-registry-server.onrender.com',
  });

  Future<Map<String, dynamic>> uploadCertificateFile(String hcvPath) async {
    final file = File(hcvPath);
    if (!await file.exists()) {
      throw Exception('File HCV non trovato: $hcvPath');
    }

    final rawCertificate = await file.readAsString();
    final parsed = jsonDecode(rawCertificate);

    if (parsed is! Map<String, dynamic>) {
      throw Exception('Certificato HCV non valido');
    }

    final hcvId = _extractHcvId(parsed);
    if (hcvId == null || hcvId.isEmpty) {
      throw Exception('HCV-ID mancante nel certificato');
    }

    final client = HttpClient();

    try {
      final uri = Uri.parse('$baseUrl/api/certificate');
      final req = await client.postUrl(uri);
      req.headers.contentType = ContentType.json;

      req.write(jsonEncode({
        'hcvId': hcvId,
        'certificateRaw': rawCertificate,
      }));

      final res = await req.close();
      final body = await utf8.decoder.bind(res).join();

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('Registry upload error ${res.statusCode}: $body');
      }

      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Risposta registry non valida');
      }

      return decoded;
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>> fetchCertificate(String hcvId) async {
    final cleaned = hcvId.trim().toUpperCase();

    if (cleaned.isEmpty) {
      throw Exception('Inserisci HCV-ID');
    }

    final client = HttpClient();

    try {
      final uri = Uri.parse('$baseUrl/api/certificate/$cleaned');
      final req = await client.getUrl(uri);
      final res = await req.close();
      final body = await utf8.decoder.bind(res).join();

      if (res.statusCode == 404) {
        throw Exception('Certificato non trovato nel registry');
      }

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('Registry fetch error ${res.statusCode}: $body');
      }

      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Risposta registry non valida');
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

      throw Exception('Certificato assente nella risposta registry');
    } finally {
      client.close(force: true);
    }
  }

  String? extractHcvIdFromCertificate(Map<String, dynamic> cert) {
    return _extractHcvId(cert);
  }

  String? _extractHcvId(Map<String, dynamic> cert) {
    final meta = cert['meta'];

    if (meta is Map && meta['hcvId'] != null) {
      return meta['hcvId'].toString();
    }

    if (cert['hcvId'] != null) {
      return cert['hcvId'].toString();
    }

    return null;
  }
}
