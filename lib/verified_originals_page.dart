import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'commercial_account_service.dart';
import 'hcv_registry_service.dart';
import 'hcv_secure_store.dart';
import 'registry_verify_page.dart';
import 'verified_originals_reference.dart';

/// Public reference discovery. This screen never certifies third-party social
/// bytes and never uploads HCVPACK/original media.
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

  bool _referenceAvailable = false;
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
        _referenceAvailable = false;
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

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 12);
    try {
      final base = _registry.baseUrl.endsWith('/')
          ? _registry.baseUrl.substring(0, _registry.baseUrl.length - 1)
          : _registry.baseUrl;
      final request = await client
          .getUrl(Uri.parse('$base/api/verified-originals/$id'))
          .timeout(const Duration(seconds: 12));
      final response =
          await request.close().timeout(const Duration(seconds: 12));
      final body = await utf8.decoder
          .bind(response)
          .join()
          .timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        throw const FormatException('Reference service unavailable');
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid Registry response');
      }
      final available = VerifiedOriginalsReference.isAvailable(
        decoded,
        requestedHcvId: id,
      );

      if (!mounted) return;
      setState(() {
        _searchedId = id;
        _referenceAvailable = available;
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
    final id = _searchedId;
    if (id == null || !_referenceAvailable || _busy) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final billing = await const CommercialAccountService().billingStatus();
      if (billing['status']?.toString() != 'active') {
        throw const CommercialAccountException(
          'SUBSCRIPTION_REQUIRED',
          statusCode: 402,
          code: 'SUBSCRIPTION_REQUIRED',
        );
      }

      final token = await HCVSecureStore.read('sigillum.auth.session.v1');
      if (token == null || token.isEmpty) {
        throw const CommercialAccountException(
          'AUTH_REQUIRED',
          statusCode: 401,
          code: 'AUTH_REQUIRED',
        );
      }

      final base = _registry.baseUrl.endsWith('/')
          ? _registry.baseUrl.substring(0, _registry.baseUrl.length - 1)
          : _registry.baseUrl;
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 12);
      try {
        final request = await client
            .getUrl(Uri.parse('$base/api/verified-originals/$id/view'))
            .timeout(const Duration(seconds: 12));
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer $token',
        );
        final response =
            await request.close().timeout(const Duration(seconds: 12));
        final body = await utf8.decoder
            .bind(response)
            .join()
            .timeout(const Duration(seconds: 12));
        final decoded = jsonDecode(body);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Invalid Registry response');
        }
        if (response.statusCode == 402) {
          throw const CommercialAccountException(
            'SUBSCRIPTION_REQUIRED',
            statusCode: 402,
            code: 'SUBSCRIPTION_REQUIRED',
          );
        }
        if (response.statusCode != 200) {
          throw const FormatException('Reference service unavailable');
        }

        final reference = VerifiedOriginalsReference.fromRegistry(
          decoded,
          requestedHcvId: id,
        );
        if (reference == null) {
          throw const FormatException('Invalid paid reference');
        }

        final opened = await launchUrl(
          reference.publicUrl,
          mode: LaunchMode.externalApplication,
        );
        if (!opened) {
          throw const FormatException('Unable to open reference');
        }
      } finally {
        client.close(force: true);
      }
    } on CommercialAccountException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.code == 'SUBSCRIPTION_REQUIRED'
            ? (_it
                ? 'La verifica resta gratuita. Per vedere l’originale certificato serve un abbonamento SIGILLUM attivo.'
                : 'Verification remains free. Viewing the certified original requires an active SIGILLUM subscription.')
            : (_it
                ? 'Accedi con un account SIGILLUM abbonato per vedere l’originale.'
                : 'Sign in with a subscribed SIGILLUM account to view the original.');
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = _it
            ? 'Impossibile aprire il contenuto certificato.'
            : 'Unable to open the certified reference.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final searched = _searchedId != null;
    final found = _referenceAvailable;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _it
              ? 'SIGILLUM · Originali certificati'
              : 'SIGILLUM · Certified references',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            _it
                ? 'Verifica il codice e, quando esiste una pubblicazione ufficiale attiva, consulta la copia di riferimento certificata.'
                : 'Check the code and, when an official active publication exists, view the certified reference copy.',
          ),
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
          FilledButton.icon(
            onPressed: _busy ? null : _lookup,
            icon: const Icon(Icons.search),
            label: Text(_it ? 'CERCA HCV-ID' : 'FIND HCV-ID'),
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.all(18),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (searched) ...[
            const SizedBox(height: 22),
            Text(
              _it
                  ? 'La presenza del codice non dimostra che il file social sia integro: un HCV-ID può essere copiato.'
                  : 'The presence of a code does not prove that a social file is intact: an HCV-ID can be copied.',
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _verifyCode,
              icon: const Icon(Icons.verified_user_outlined),
              label: Text(
                _it
                    ? 'VERIFICA CODICE E CERTIFICATO'
                    : 'CHECK CODE AND CERTIFICATE',
              ),
            ),
            const SizedBox(height: 18),
            if (found) ...[
              Text(
                _it
                    ? 'Originale certificato disponibile. La visualizzazione richiede un abbonamento SIGILLUM attivo.'
                    : 'Certified original available. Viewing requires an active SIGILLUM subscription.',
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _openReference,
                icon: const Icon(Icons.lock_outline),
                label: Text(
                  _it
                      ? 'GUARDA L’ORIGINALE CERTIFICATO'
                      : 'WATCH THE CERTIFIED ORIGINAL',
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _it
                    ? 'SIGILLUM non rende pubblico il link durante la verifica gratuita. Il riferimento viene richiesto solo dopo il controllo dell’abbonamento.'
                    : 'SIGILLUM does not expose the link during free verification. The reference is requested only after the subscription check.',
              ),
            ] else
              Text(
                _it
                    ? 'Nessun originale certificato attivo disponibile. Il certificato può comunque essere verificato gratuitamente.'
                    : 'No active certified original is available. The certificate can still be checked for free.',
              ),
          ],
        ],
      ),
    );
  }
}
