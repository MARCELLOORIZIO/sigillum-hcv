import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'hcv_registry_service.dart';
import 'hcv_secure_store.dart';

/// Records creator consent only: NEVER uploads the HCVPACK or posts to YouTube.
class VerifiedOriginalsConsentPage extends StatefulWidget {
  const VerifiedOriginalsConsentPage({super.key});
  @override
  State<VerifiedOriginalsConsentPage> createState() => _ConsentState();
}

class _ConsentState extends State<VerifiedOriginalsConsentPage> {
  final _id = TextEditingController();
  final _registry = const HCVRegistryService();
  static final _idPattern = RegExp(r'^HCV-[A-F0-9]{16}$');
  static final _hashPattern = RegExp(r'^[a-f0-9]{64}$');
  String? _resolvedId, _originalHash, _message;
  String _state = 'NONE';
  bool _publish = false, _rights = false, _monetize = false, _busy = false;

  @override
  void dispose() { _id.dispose(); super.dispose(); }

  Future<Map<String, dynamic>> _call(String method, String path,
      {Map<String, dynamic>? payload}) async {
    final token = await HCVSecureStore.read('sigillum.auth.session.v1');
    if (token == null || token.isEmpty) {
      throw const FormatException('Sessione Creator mancante');
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await client.openUrl(method,
          Uri.parse(_registry.baseUrl + path))
          .timeout(const Duration(seconds: 15));
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer ' + token);
      req.headers.contentType = ContentType.json;
      if (payload != null) req.write(jsonEncode(payload));
      final res = await req.close().timeout(const Duration(seconds: 15));
      final raw = await utf8.decoder.bind(res).join()
          .timeout(const Duration(seconds: 15));
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) {
        throw const FormatException('Risposta Registry non valida');
      }
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw FormatException(json['error']?.toString()
            ?? 'HTTP ' + res.statusCode.toString());
      }
      return json;
    } finally { client.close(force: true); }
  }

  Future<void> _resolve() async {
    final id = _id.text.trim().toUpperCase();
    if (!_idPattern.hasMatch(id)) {
      setState(() => _message = 'HCV-ID non valido'); return;
    }
    setState(() {
      _busy = true; _resolvedId = null; _originalHash = null; _message = null;
    });
    try {
      final cert = await _registry.fetchCertificate(id);
      final meta = cert['meta'], content = cert['content'];
      final hash = content is Map ? content['hash'] : null;
      if (meta is! Map || meta['hcvId'] != id ||
          hash is! String || !_hashPattern.hasMatch(hash)) {
        throw const FormatException('Certificato non valido');
      }
      final status = await _call('GET',
          '/api/verified-originals/consents/' + id);
      if (!mounted) return;
      setState(() {
        _resolvedId = id; _originalHash = hash;
        _state = status['consentState']?.toString() ?? 'NONE';
        _publish = false; _rights = false; _monetize = false;
        _message = _state == 'ACTIVE'
            ? 'Consenso attivo: puoi ritirarlo.'
            : 'Certificato trovato. Nessun contenuto è ancora pubblicato.';
      });
    } catch (e) {
      if (mounted) setState(() => _message = 'Verifica non riuscita: ' + e.toString());
    } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _grant() async {
    if (_resolvedId == null || _originalHash == null ||
        !_publish || !_rights || _state == 'ACTIVE') return;
    setState(() => _busy = true);
    try {
      await _call('POST', '/api/verified-originals/consents', payload: {
        'hcvId': _resolvedId, 'originalSha256': _originalHash,
        'intent': 'PUBLISH_VERIFIED_ORIGINAL',
        'publishReference': true, 'rightsConfirmed': true,
        'monetize': _monetize,
      });
      if (mounted) setState(() {
        _state = 'ACTIVE';
        _message = 'Consenso registrato: il video NON è stato pubblicato. '
            'La pubblicazione richiede ancora la verifica e il canale ufficiale.';
      });
    } catch (e) {
      if (mounted) setState(() => _message = 'Consenso non registrato: ' + e.toString());
    } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _withdraw() async {
    if (_resolvedId == null || _state != 'ACTIVE') return;
    setState(() => _busy = true);
    try {
      await _call('POST',
          '/api/verified-originals/consents/' + _resolvedId! + '/withdraw');
      if (mounted) setState(() {
        _state = 'WITHDRAWN';
        _message = 'Riferimento nascosto nel Registry. '
            'L’eventuale rimozione YouTube deve essere confermata da SIGILLUM.';
      });
    } catch (e) {
      if (mounted) setState(() => _message = 'Ritiro non riuscito: ' + e.toString());
    } finally { if (mounted) setState(() => _busy = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pubblica un originale SIGILLUM')),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Questa schermata registra il consenso. '
          'Non carica video, non invia l’HCVPACK e non pubblica su YouTube.'),
      const SizedBox(height: 16),
      TextField(controller: _id, enabled: !_busy,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(labelText: 'HCV-ID',
          hintText: 'HCV-0123456789ABCDEF', border: OutlineInputBorder())),
      OutlinedButton(onPressed: _busy ? null : _resolve,
        child: const Text('CONTROLLA IL MIO CERTIFICATO')),
      if (_busy) const Center(child: CircularProgressIndicator()),
      if (_resolvedId != null) ...[
        Text('Certificato: ' + _resolvedId!),
        if (_state != 'ACTIVE') ...[
          CheckboxListTile(value: _publish,
            onChanged: _busy ? null : (v) => setState(() => _publish = v == true),
            title: const Text('Autorizzo la pubblicazione della copia audiovisiva di riferimento.')),
          CheckboxListTile(value: _rights,
            onChanged: _busy ? null : (v) => setState(() => _rights = v == true),
            title: const Text('Confermo di disporre dei diritti e dei consensi necessari, anche sull’audio.')),
          SwitchListTile(value: _monetize,
            onChanged: _busy ? null : (v) => setState(() => _monetize = v),
            title: const Text('Autorizzo separatamente l’eventuale monetizzazione.'),
            subtitle: const Text('Facoltativo: disattivato per impostazione iniziale.')),
          FilledButton(onPressed: !_busy && _publish && _rights ? _grant : null,
            child: const Text('REGISTRA IL MIO CONSENSO')),
        ] else FilledButton.tonal(onPressed: _busy ? null : _withdraw,
          child: const Text('RITIRA IL CONSENSO')),
      ],
      if (_message != null) Padding(padding: const EdgeInsets.only(top: 16),
        child: Text(_message!)),
      const SizedBox(height: 18),
      const Text('Un HCV-ID valido non dimostra che un file social esterno sia integro.'),
    ]),
  );
