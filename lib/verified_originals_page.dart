import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'commercial_account_service.dart';
import 'hcv_import_router_page.dart';
import 'hcv_registry_service.dart';
import 'hcv_secure_store.dart';
import 'registry_verify_page.dart';
import 'sigillum_localization.dart';
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

  String _t(String key) => SigillumCopy.t(widget.languageCode, key);

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
        _error = _t('voInvalidId');
      });
      return;
    }

    setState(() {
      _busy = true;
      _searchedId = null;
      _referenceAvailable = false;
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
        _error = _t('voRegistryError');
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
            ? _t('voSubscriptionRequired')
            : _t('voAuthRequired');
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = _t('voOpenError');
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickFile() async {
    try {
      final selected = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: false,
        type: FileType.any,
      );
      final path = selected?.files.single.path;
      if (path == null || path.isEmpty || !mounted) return;

      final filename = path.split(Platform.pathSeparator).last.toUpperCase();
      final fromName = RegExp(r'HCV-[A-F0-9]{16}').firstMatch(filename)?.group(0);
      if (fromName != null) {
        _controller.text = fromName;
        await _lookup();
        if (!mounted) return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => HCVImportRouterPage(
            path: path,
            languageCode: widget.languageCode,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = _t('voFilePickError'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final searched = _searchedId != null;
    final found = _referenceAvailable;

    return Scaffold(
      appBar: AppBar(title: Text(_t('voPageTitle'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(_t('voIntro')),
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
            label: Text(_t('voFindId')),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _busy ? null : _pickFile,
            icon: const Icon(Icons.folder_open_outlined),
            label: Text(_t('voSelectFile')),
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
            Text(_t('voCodeWarning')),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _verifyCode,
              icon: const Icon(Icons.verified_user_outlined),
              label: Text(_t('voVerifyCodeCertificate')),
            ),
            const SizedBox(height: 18),
            if (found) ...[
              Text(_t('voAvailable')),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _openReference,
                icon: const Icon(Icons.lock_outline),
                label: Text(_t('voWatch')),
              ),
              const SizedBox(height: 10),
              Text(_t('voLinkGated')),
            ] else
              Text(_t('voNotAvailable')),
          ],
        ],
      ),
    );
  }
}
