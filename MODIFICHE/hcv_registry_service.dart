import 'dart:convert';
import 'dart:io';

class HCVRegistryService {
  // Android emulator -> host PC: 10.0.2.2
  // Real phone -> replace with your PC/server LAN IP, for example:
  // http://192.168.1.50:8080
  final String baseUrl;

  const HCVRegistryService({this.baseUrl = 'http://10.0.2.2:8080'});

  Future<Map<String, dynamic>> uploadCertificateFile(String hcvPath) async {
    final file = File(hcvPath);
    if (!await file.exists()) {
      throw Exception('File HCV non trovato: $hcvPath');
    }

    final raw = await file.readAsString();
    final data = jsonDecode(raw);

    if (data is! Map<String, dynamic>) {
      throw Exception('Certificato HCV non valido');
    }

    final hcvId = _extractHcvId(data);
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
        'certificate': data,
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

      final certificate = decoded['certificate'];
      if (certificate is! Map<String, dynamic>) {
        throw Exception('Certificato assente nella risposta registry');
      }

      return certificate;
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
