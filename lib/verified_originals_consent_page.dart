import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'hcv_registry_service.dart';
import 'hcv_secure_store.dart';

/// Records creator consent and can send the selected exact original to the
/// SIGILLUM backend. The app never receives social-platform credentials and
/// never uploads directly to a social platform.
class VerifiedOriginalsConsentPage extends StatefulWidget {
  const VerifiedOriginalsConsentPage({super.key});

  @override
  State<VerifiedOriginalsConsentPage> createState() => _ConsentState();
}

class _ConsentState extends State<VerifiedOriginalsConsentPage> {
  final TextEditingController _id = TextEditingController();
  final HCVRegistryService _registry = const HCVRegistryService();
  static final RegExp _idPattern = RegExp(r'^HCV-[A-F0-9]{16}$');
  static final RegExp _hashPattern = RegExp(r'^[a-f0-9]{64}$');

  String? _resolvedId;
  String? _originalHash;
  String? _consentRecordId;
  String? _message;
  String _state = 'NONE';
  bool _publish = false;
  bool _rights = false;
  bool _monetizationConsent = false;
  bool _busy = false;

  @override
  void dispose() {
    _id.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _call(
    String method,
    String path, {
    Map<String, dynamic>? payload,
  }) async {
    final token = await HCVSecureStore.read('sigillum.auth.session.v1');
    if (token == null || token.isEmpty) {
      throw const FormatException('Sessione Creator mancante');
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final base = _registry.baseUrl.endsWith('/')
          ? _registry.baseUrl.substring(0, _registry.baseUrl.length - 1)
          : _registry.baseUrl;
      final req = await client
          .openUrl(method, Uri.parse('$base$path'))
          .timeout(const Duration(seconds: 15));
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      req.headers.contentType = ContentType.json;
      if (payload != null) req.write(jsonEncode(payload));
      final res = await req.close().timeout(const Duration(seconds: 15));
      final raw = await utf8.decoder
          .bind(res)
          .join()
          .timeout(const Duration(seconds: 15));
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Risposta Registry non valida');
      }
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw FormatException(
          decoded['error']?.toString() ?? 'HTTP ${res.statusCode}',
        );
      }
      return decoded;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _resolve() async {
    final id = _id.text.trim().toUpperCase();
    if (!_idPattern.hasMatch(id)) {
      setState(() => _message = 'HCV-ID non valido');
      return;
    }
    setState(() {
      _busy = true;
      _resolvedId = null;
      _originalHash = null;
      _consentRecordId = null;
      _message = null;
    });
    try {
      final cert = await _registry.fetchCertificate(id);
      final meta = cert['meta'];
      final content = cert['content'];
      final hash = content is Map ? content['hash'] : null;
      if (meta is! Map ||
          meta['hcvId'] != id ||
          hash is! String ||
          !_hashPattern.hasMatch(hash)) {
        throw const FormatException('Certificato non valido');
      }
      final status = await _call('GET', '/api/verified-originals/consents/$id');
      if (!mounted) return;
      setState(() {
        _resolvedId = id;
        _originalHash = hash;
        _state = status['consentState']?.toString() ?? 'NONE';
        _consentRecordId = status['recordId']?.toString();
        _publish = false;
        _rights = false;
        _monetizationConsent = status['monetizationConsent'] == true;
        _message = _state == 'ACTIVE'
            ? 'Consenso attivo: puoi ritirarlo.'
            : 'Certificato trovato. Nessun contenuto viene pubblicato da questa schermata.';
      });
    } catch (error) {
      if (mounted) {
        setState(() => _message = 'Verifica non riuscita: $error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _grant() async {
    if (_resolvedId == null ||
        _originalHash == null ||
        !_publish ||
        !_rights ||
        _state == 'ACTIVE') {
      return;
    }
    setState(() => _busy = true);
    try {
      final response = await _call('POST', '/api/verified-originals/consents', payload: {
        'hcvId': _resolvedId,
        'intent': 'PUBLISH_VERIFIED_ORIGINAL',
        'publishReference': true,
        'rightsConfirmed': true,
        'monetizationConsent': _monetizationConsent,
      });
      if (mounted) {
        setState(() {
          _state = 'ACTIVE';
          _consentRecordId = response['recordId']?.toString();
          _message =
              'Consenso registrato. Ora puoi selezionare l’esatto video originale. '
              'Il server lo accetterà solo se SHA-256 e dimensione coincidono con il certificato.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _message = 'Consenso non registrato: $error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _withdraw() async {
    if (_resolvedId == null || _state != 'ACTIVE') return;
    setState(() => _busy = true);
    try {
      await _call(
        'POST',
        '/api/verified-originals/consents/${_resolvedId!}/withdraw',
      );
      if (mounted) {
        setState(() {
          _state = 'WITHDRAWN';
          _consentRecordId = null;
          _message =
              'Riferimento nascosto nel Registry. La revoca del certificato '
              'è un evento separato e non è stata eseguita.';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _message = 'Ritiro non riuscito: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _publishOriginal() async {
    final hcvId = _resolvedId;
    final consentRecordId = _consentRecordId;
    if (hcvId == null ||
        consentRecordId == null ||
        consentRecordId.isEmpty ||
        _state != 'ACTIVE' ||
        _busy) {
      return;
    }

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
      withData: false,
    );
    final path = picked?.files.single.path;
    if (path == null || !path.toLowerCase().endsWith('.mp4')) {
      if (mounted) {
        setState(() {
          _message =
              'Seleziona il file MP4 originale certificato da SIGILLUM.';
        });
      }
      return;
    }

    final file = File(path);
    final size = await file.length();
    if (size <= 0) {
      if (mounted) setState(() => _message = 'File originale non leggibile.');
      return;
    }

    final token = await HCVSecureStore.read('sigillum.auth.session.v1');
    if (token == null || token.isEmpty) {
      if (mounted) setState(() => _message = 'Sessione Creator mancante.');
      return;
    }

    setState(() {
      _busy = true;
      _message =
          'Invio dell’originale al servizio SIGILLUM. Il server verificherà '
          'i byte prima di qualsiasi pubblicazione.';
    });

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final base = _registry.baseUrl.endsWith('/')
          ? _registry.baseUrl.substring(0, _registry.baseUrl.length - 1)
          : _registry.baseUrl;
      final uri = Uri.parse(
        '$base/api/verified-originals/publish/$hcvId',
      ).replace(queryParameters: {
        'consentRecordId': consentRecordId,
        'monetizationEnabled': _monetizationConsent.toString(),
      });

      final request =
          await client.postUrl(uri).timeout(const Duration(seconds: 20));
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer $token',
      );
      request.headers.contentType = ContentType('video', 'mp4');
      request.contentLength = size;
      await request.addStream(file.openRead());

      final response =
          await request.close().timeout(const Duration(minutes: 15));
      final raw = await utf8.decoder
          .bind(response)
          .join()
          .timeout(const Duration(minutes: 2));
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Risposta Registry non valida');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw FormatException(
          decoded['error']?.toString() ?? 'HTTP ${response.statusCode}',
        );
      }

      if (!mounted) return;
      final publicUrl = decoded['publicUrl']?.toString() ?? '';
      setState(() {
        _message = publicUrl.isEmpty
            ? 'Pubblicazione completata e registrata nel Registry.'
            : 'Pubblicazione completata e registrata nel Registry: $publicUrl';
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _message =
              'Pubblicazione non completata. Nessun riferimento viene mostrato '
              'come verificato: $error';
        });
      }
    } finally {
      client.close(force: true);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pubblica un originale SIGILLUM')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Prima registri il consenso; poi puoi selezionare l’esatto video '
            'originale. Il file viene inviato solo al backend SIGILLUM, che '
            'verifica SHA-256 e dimensione prima di creare la copia di riferimento. '
            'Nessuna credenziale social è presente nell’app.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _id,
            enabled: !_busy,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'HCV-ID',
              hintText: 'HCV-0123456789ABCDEF',
              border: OutlineInputBorder(),
            ),
          ),
          OutlinedButton(
            onPressed: _busy ? null : _resolve,
            child: const Text('CONTROLLA IL MIO CERTIFICATO'),
          ),
          if (_busy) const Center(child: CircularProgressIndicator()),
          if (_resolvedId != null) ...[
            Text('Certificato: ${_resolvedId!}'),
            if (_state != 'ACTIVE') ...[
              CheckboxListTile(
                value: _publish,
                onChanged:
                    _busy ? null : (v) => setState(() => _publish = v == true),
                title: const Text(
                  'Autorizzo la pubblicazione della copia di riferimento.',
                ),
              ),
              CheckboxListTile(
                value: _rights,
                onChanged:
                    _busy ? null : (v) => setState(() => _rights = v == true),
                title: const Text(
                  'Confermo di disporre dei diritti e dei consensi necessari, '
                  'inclusi immagini, video e audio incorporato.',
                ),
              ),
              SwitchListTile(
                value: _monetizationConsent,
                onChanged: _busy
                    ? null
                    : (v) => setState(() => _monetizationConsent = v),
                title: const Text(
                  'Autorizzo separatamente l’eventuale monetizzazione.',
                ),
                subtitle: const Text(
                  'Facoltativo e disattivato per impostazione iniziale.',
                ),
              ),
              FilledButton(
                onPressed: !_busy && _publish && _rights ? _grant : null,
                child: const Text('REGISTRA IL MIO CONSENSO'),
              ),
            ] else ...[
              FilledButton.icon(
                onPressed: _busy ? null : _publishOriginal,
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text('SELEZIONA E PUBBLICA IL VIDEO ORIGINALE'),
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: _busy ? null : _withdraw,
                child: const Text('RITIRA IL CONSENSO'),
              ),
            ],
          ],
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(_message!),
            ),
          const SizedBox(height: 18),
          const Text(
            'Un HCV-ID valido o una somiglianza visiva non dimostrano '
            'l’integrità esatta di un file social esterno.',
          ),
        ],
      ),
    );
  }
}
