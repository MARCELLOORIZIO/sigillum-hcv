import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'hcv_registry_service.dart';
import 'registry_verify_page.dart';
import 'verified_originals_reference.dart';

/// A reference-discovery screen, not a new media-integrity verdict.
/// It never uploads an HCVPACK and never certifies third-party social bytes.
class VerifiedOriginalsPage extends StatefulWidget {
  const VerifiedOriginalsPage({
    super.key,
    this.initialHcvId,
    this.languageCode = 'it',
  });

  final String? initialHcvId;
  final String languageCode;

  @override
  State<VerifiedOriginalsPage> createState() => _VerifiedOriginalsPageState();
}

class _VerifiedOriginalsPageState extends State<VerifiedOriginalsPage> {
  static final RegExp _validId = RegExp(r'^HCV-[A-F0-9]{16}$');
  final HCVRegistryService _registry = const HCVRegistryService();
  final TextEditingController _controller = TextEditingController();
  VerifiedOriginalsReference? _reference;
  String? _searchedId;
  String? _error;
  bool _busy = false;

  bool get _it => widget.languageCode == 'it';

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialHcvId ?? '';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    final id = _controller.text.trim().toUpperCase();
    if (!_validId.hasMatch(id)) {
      setState(() {
        _searchedId = null;
        _reference = null;
        _error = _it ? 'HCV-ID non valido.' : 'Invalid HCV-ID.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _searchedId = null;
      _reference = null;
      _error = null;
    });

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    try {
      final base = _registry.baseUrl.endsWith('/')
          ? _registry.baseUrl.substring(0, _registry.baseUrl.length - 1)
          : _registry.baseUrl;
      final url = Uri.parse(base + '/api/verified-originals/' + id);
      final request = await client.getUrl(url).timeout(const Duration(seconds: 12));
      final response = await request.close().timeout(const Duration(seconds: 12));
      final body = await utf8.decoder.bind(response).join().timeout(
        const Duration(seconds: 12),
      );
      if (response.statusCode != 200) {
        throw const FormatException('Reference service unavailable');
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid Registry response');
      }
      final ref = VerifiedOriginalsReference.fromRegistry(
        decoded,
        requestedHcvId: id,
      );
      if (!mounted) return;
      setState(() {
        _searchedId = id;
        _reference = ref;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = _it
            ? 'Registry non raggiungibile o risposta non valida. Nessun risultato di verifica.'
            : 'Registry unavailable or invalid response. No verification result.';
      });
    } finally {
      client.close(force: true);
      if (mounted) setState(() => _busy = false);
    }
  }

  void _verifyCode() {
    final id = _searchedId;
    if (id == null) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => RegistryVerifyPage(
        initialHcvId: id,
        languageCode: widget.languageCode,
      ),
    ));
  }

  Future<void> _openReference() async {
    final ref = _reference;
    if (ref == null) return;
    if (!await launchUrl(ref.youtubeUrl, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_it
            ? 'Impossibile aprire la copia di riferimento.'
            : 'Unable to open the reference.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final searched = _searchedId != null;
    final found = _reference != null;
    return Scaffold(
      appBar: AppBar(title: Text(_it
          ? 'SIGILLUM · Originali certificati'
          : 'SIGILLUM · Certified references')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(_it
              ? 'Controlla il certificato HCV e, se A ha autorizzato la pubblicazione, apri la copia audiovisiva di riferimento.'
              : 'Check the HCV certificate and, if the creator opted in, open the audiovisual reference.'),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            textCapitalization: TextCapitalization.characters,
            maxLength: 20,
            decoration: const InputDecoration(
              labelText: 'HCV-ID',
              hintText: 'HCV-0123456789ABCDEF',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _lookup(),
          ),
          ElevatedButton.icon(
            onPressed: _busy ? null : _lookup,
            icon: const Icon(Icons.search),
            label: Text(_it ? 'CERCA HCV-ID' : 'FIND HCV-ID'),
          ),
          if (_busy) const Padding(
            padding: EdgeInsets.all(18),
            child: Center(child: CircularProgressIndicator()),
          ),
          if (_error != null) Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_error!, style: const TextStyle(color: Colors.deepOrange)),
          ),
          if (searched) ...[
            const SizedBox(height: 22),
            Text(_it
                ? 'La presenza del codice non dimostra che il file social sia integro.'
                : 'An HCV-ID alone does not prove integrity of the social file.'),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _verifyCode,
              icon: const Icon(Icons.verified_user_outlined),
              label: Text(_it ? 'VERIFICA CODICE E CERTIFICATO' : 'CHECK CODE AND CERTIFICATE'),
            ),
            const SizedBox(height: 18),
            if (found) ...[
              Text(_it
                  ? 'Copia audiovisiva di riferimento disponibile.'
                  : 'Audiovisual reference available.'),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _openReference,
                icon: const Icon(Icons.play_circle_outline),
                label: Text(_it
                    ? 'GUARDA IL CONTENUTO CERTIFICATO'
                    : 'WATCH THE CERTIFIED REFERENCE'),
              ),
            ] else Text(_it
                ? 'Nessuna copia audiovisiva pubblica disponibile: il certificato può comunque essere verificabile.'
                : 'No public audiovisual reference available; the certificate may still be verifiable.'),
            const SizedBox(height: 22),
            Text(_it
                ? 'Il video ospitato su YouTube è una copia di riferimento. Confrontalo visivamente e acusticamente con il post sospetto. Non è una prova automatica che il file social sia identico.'
                : 'YouTube hosts a reference copy. Compare it with the suspect post. This does not automatically verify the social file.'),
          ],
        ],
      ),
    );
  }
}
