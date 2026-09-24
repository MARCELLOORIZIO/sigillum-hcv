import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'hcv_secure_store.dart';

/// Reference links are NOT cryptographic verification of an arbitrary social file.
class VerifiedOriginalsPage extends StatefulWidget {
  const VerifiedOriginalsPage({super.key, this.initialHcvId});
  final String? initialHcvId;

  @override
  State<VerifiedOriginalsPage> createState() => _VerifiedOriginalsPageState();
}

class _VerifiedOriginalsPageState extends State<VerifiedOriginalsPage> {
  static const _base = String.fromEnvironment(
    'SIGILLUM_API_BASE_URL',
    defaultValue: 'https://sigillum-registry-production.onrender.com',
  );
  final _id = TextEditingController();
  bool _loading = false;
  bool _rights = false;
  bool _public = false;
  bool _monetize = false;
  bool _certified = false;
  String? _reference;
  String? _error;

  @override
  void initState() {
    super.initState();
    _id.text = widget.initialHcvId ?? '';
    if (_id.text.isNotEmpty) Future.microtask(_load);
  }

  @override
  void dispose() {
    _id.dispose();
    super.dispose();
  }

  String get _hcvId => _id.text.trim().toUpperCase();

  Future<Map<String, dynamic>> _request(String path, {Object? post}) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    try {
      final uri = Uri.parse('$_base$path');
      final request = await (post == null
              ? client.getUrl(uri)
              : client.postUrl(uri))
          .timeout(const Duration(seconds: 12));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (post != null) {
        final token = await HCVSecureStore.read('sigillum.auth.session.v1');
        if (token == null || token.isEmpty) {
          throw const FormatException('Accedi come Creator per autorizzare la pubblicazione.');
        }
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(post));
      }
      final response = await request.close().timeout(const Duration(seconds: 12));
      final data = jsonDecode(await utf8.decoder
          .bind(response)
          .join()
          .timeout(const Duration(seconds: 12)));
      if (data is! Map<String, dynamic>) {
        throw const FormatException('Risposta del Registry non valida.');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw FormatException('${data['error'] ?? 'Errore Registry'} (${response.statusCode})');
      }
      return data;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _load() async {
    if (_loading) return;
    if (!RegExp(r'^HCV-[A-F0-9]{16}$').hasMatch(_hcvId)) {
      setState(() => _error = 'Inserisci un HCV-ID valido.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _certified = false;
      _reference = null;
    });
    try {
      final result = await _request('/api/verified-originals/$_hcvId');
      if (!mounted) return;
      setState(() {
        _certified = result['certificateVerified'] == true;
        final reference = result['reference'];
        if (result['referenceAvailable'] == true && reference is Map) {
          final rawUrl = reference['url'];
          if (rawUrl is String) {
            final uri = Uri.tryParse(rawUrl);
            if (uri != null && uri.scheme == 'https' &&
                uri.host == 'www.youtube.com') {
              _reference = uri.toString();
            }
          }
        }
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _consent() async {
    if (_loading || !_rights || !_public || !_certified) return;
    setState(() { _loading = true; _error = null; });
    try {
      await _request('/api/verified-originals/$_hcvId/consent', post: {
        'allowPublication': true,
        'allowMonetization': _monetize,
        'rightsConfirmed': true,
        'publicVisibilityAcknowledged': true,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(
          'Consenso registrato. La pubblicazione richiede ancora una revisione SIGILLUM.',
        )));
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _revoke() async {
    if (_loading || !_certified) return;
    setState(() { _loading = true; _error = null; });
    try {
      await _request('/api/verified-originals/$_hcvId/revoke', post: {});
      if (mounted) {
        setState(() => _reference = null);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(
          'Consenso ritirato. SIGILLUM deve inoltre chiedere la rimozione del post sulla piattaforma.',
        )));
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      setState(() => _error = 'Impossibile aprire il collegamento.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SIGILLUM Verified Originals')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('Verifica il certificato o consulta la copia di riferimento sul canale ufficiale SIGILLUM.'),
        const SizedBox(height: 16),
        TextField(
          controller: _id,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'HCV-ID', hintText: 'HCV-0123456789ABCDEF', border: OutlineInputBorder()),
          onChanged: (_) => setState(() { _certified = false; _reference = null; _error = null; }),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.verified_outlined),
          label: const Text('Verifica codice'),
        ),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (_certified) ...[
          const SizedBox(height: 12),
          const Text('Certificato registrato e verificato. Questo non dimostra che un file social con lo stesso codice sia integro.'),
          OutlinedButton.icon(
            onPressed: () => _openUrl('$_base/verify/$_hcvId'),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Apri dettagli certificato'),
          ),
          if (_reference != null)
            FilledButton.icon(
              onPressed: () => _openUrl(_reference!),
              icon: const Icon(Icons.play_circle_outline),
              label: const Text('Guarda il riferimento ufficiale'),
            )
          else const Text('Nessuna copia pubblica disponibile con consenso attivo.'),
          const Divider(height: 36),
          const Text('Se sei l’autore, puoi autorizzare SIGILLUM a pubblicare una copia di riferimento. Non viene pubblicato nulla automaticamente.'),
          CheckboxListTile(
            value: _rights, onChanged: _loading ? null : (v) => setState(() => _rights = v == true),
            title: const Text('Confermo i diritti necessari su video, persone e audio.'),
          ),
          CheckboxListTile(
            value: _public, onChanged: _loading ? null : (v) => setState(() => _public = v == true),
            title: const Text('Autorizzo la pubblicazione pubblica della copia di riferimento.'),
          ),
          CheckboxListTile(
            value: _monetize, onChanged: _loading ? null : (v) => setState(() => _monetize = v == true),
            title: const Text('Autorizzo separatamente la monetizzazione, se ammessa dalla piattaforma.'),
          ),
          FilledButton(
            onPressed: _loading || !_rights || !_public ? null : _consent,
            child: const Text('Registra il mio consenso'),
          ),
          TextButton(
            onPressed: _loading ? null : _revoke,
            child: const Text('Ritira il consenso SIGILLUM'),
          ),
          const Text('Il ritiro disattiva subito il link nel Registry; la rimozione dal social richiede una richiesta separata alla piattaforma.'),
        ],
      ]),
    );
  }
}