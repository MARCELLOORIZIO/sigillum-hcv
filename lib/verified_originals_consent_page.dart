import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'hcv_registry_service.dart';
import 'hcv_secure_store.dart';

/// Records creator consent only. It never uploads HCVPACK/original media and
/// never posts directly to a social platform.
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
        _publish = false;
        _rights = false;
        _monetizationConsent = false;
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
      await _call('POST', '/api/verified-originals/consents', payload: {
        'hcvId': _resolvedId,
        'intent': 'PUBLISH_VERIFIED_ORIGINAL',
        'publishReference': true,
        'rightsConfirmed': true,
        'monetizationConsent': _monetizationConsent,
      });
      if (mounted) {
        setState(() {
          _state = 'ACTIVE';
          _message =
              'Consenso registrato. Nessun file è stato caricato o pubblicato: '
              'SIGILLUM dovrà prima generare e registrare una copia di riferimento fidata.';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pubblica un originale SIGILLUM')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Questa schermata registra soltanto il consenso. Non carica media, '
            'non invia HCVPACK e non contiene credenziali della piattaforma.',
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
            ] else
              FilledButton.tonal(
                onPressed: _busy ? null : _withdraw,
                child: const Text('RITIRA IL CONSENSO'),
              ),
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
