import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'hcv_identity.dart';
import 'hcv_registry_service.dart';

class ProductionIdentityPage extends StatefulWidget {
  const ProductionIdentityPage({
    super.key,
    this.languageCode = 'it',
  });

  final String languageCode;

  @override
  State<ProductionIdentityPage> createState() =>
      _ProductionIdentityPageState();
}

class _ProductionIdentityPageState extends State<ProductionIdentityPage>
    with WidgetsBindingObserver {
  final TextEditingController _nameController = TextEditingController();
  final HCVIdentity _identityStore = HCVIdentity();
  final HCVRegistryService _registry = const HCVRegistryService();

  Map<String, dynamic> _identity = const {};
  String _status = 'Caricamento identita tecnica...';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(_loadIdentity);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _sessionId.isNotEmpty) {
      Future.microtask(() => _refreshKyc(silent: true));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nameController.dispose();
    super.dispose();
  }

  String get _creatorId => _identity['creatorId']?.toString() ?? '';
  String get _creatorName => _identity['creatorName']?.toString() ?? '';
  String get _keyFingerprint =>
      _identity['devicePublicKeyFingerprint']?.toString() ?? '';
  String get _sessionId => _identity['kycSessionId']?.toString() ?? '';
  String get _kycStatus => _identity['kycStatus']?.toString() ?? 'not_started';
  bool get _verified => _kycStatus == 'verified';

  Future<void> _loadIdentity({bool attemptRecovery = true}) async {
    if (mounted) setState(() => _loading = true);
    try {
      final identity = await _identityStore.loadIdentity(
        attemptKycRecovery: attemptRecovery,
      );
      if (!mounted) return;
      final recoveryError = identity['kycRecoveryError']?.toString() ?? '';
      final kycStatus = identity['kycStatus']?.toString() ?? 'not_started';
      setState(() {
        _identity = identity;
        _nameController.text = identity['creatorName']?.toString() ?? '';
        _loading = false;
        if (kycStatus == 'verified') {
          _status = 'Identita legale verificata e recuperata dal Registry';
        } else if (recoveryError.isNotEmpty) {
          _status = 'Recupero KYC non completato: $recoveryError';
        } else if (identity['kycSessionId']?.toString().isNotEmpty == true) {
          _status = 'Sessione KYC presente: $kycStatus';
        } else {
          _status = 'Identita tecnica pronta. KYC non ancora verificato.';
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _status = 'Errore caricamento identita: $error';
      });
    }
  }

  Future<void> _saveDeclaredName() async {
    if (_verified) {
      setState(() {
        _status = 'Il nome e determinato dalla verifica legale Stripe.';
      });
      return;
    }
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _status = 'Inserisci un nome dichiarato');
      return;
    }
    await _identityStore.saveCreatorName(name);
    await _loadIdentity(attemptRecovery: false);
    if (mounted) setState(() => _status = 'Nome dichiarato salvato');
  }

  Future<void> _recoverKyc() async {
    setState(() {
      _loading = true;
      _status = 'Recupero KYC dal Registry e da Stripe...';
    });
    try {
      final identity = await _identityStore.loadIdentity(
        attemptKycRecovery: false,
      );
      final publicKey = identity['publicKey'];
      if (publicKey is! Map || _keyFingerprint.isEmpty) {
        throw StateError('Chiave pubblica del dispositivo non disponibile');
      }
      final remote = await _registry.recoverKycSession(
        creatorId: identity['creatorId']?.toString() ?? '',
        creatorName: identity['creatorName']?.toString() ?? '',
        deviceKeyFingerprint:
            identity['devicePublicKeyFingerprint']?.toString() ?? '',
        publicKey: Map<String, dynamic>.from(publicKey),
      );
      if (remote['found'] != true) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _status = 'Nessuna verifica KYC associata a questo dispositivo.';
        });
        return;
      }
      await _saveRemoteKyc(remote);
      await _loadIdentity(attemptRecovery: false);
      if (mounted) {
        setState(() {
          _status = remote['verified'] == true
              ? 'KYC recuperato: identita verificata'
              : _remoteStatusText(remote);
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _status = 'Recupero KYC non riuscito: $error';
      });
    }
  }

  Future<void> _startOrResumeKyc() async {
    setState(() {
      _loading = true;
      _status = 'Preparazione verifica Stripe Identity...';
    });
    try {
      final identity = await _identityStore.loadIdentity(
        attemptKycRecovery: false,
      );
      final remote = await _registry.startKycSession(
        creatorId: identity['creatorId']?.toString() ?? '',
        creatorName: identity['creatorName']?.toString() ?? 'Local Creator',
        deviceKeyFingerprint:
            identity['devicePublicKeyFingerprint']?.toString(),
        publicKey: identity['publicKey'] is Map
            ? Map<String, dynamic>.from(identity['publicKey'] as Map)
            : null,
      );
      await _saveRemoteKyc(remote);
      await _loadIdentity(attemptRecovery: false);
      final url = remote['url']?.toString() ?? '';
      final remoteStatus = remote['status']?.toString() ?? 'unknown';
      if (remoteStatus == 'requires_input' && url.isNotEmpty) {
        final opened = await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );
        if (!opened && mounted) {
          setState(() {
            _status = 'Apri manualmente il link Stripe:\n$url';
          });
        }
      } else if (mounted) {
        setState(() => _status = _remoteStatusText(remote));
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _status = 'Stripe KYC non disponibile: $error';
      });
    }
  }

  Future<void> _refreshKyc({bool silent = false}) async {
    final sessionId = _sessionId;
    if (sessionId.isEmpty) {
      if (!silent) setState(() => _status = 'Nessuna sessione KYC presente');
      return;
    }
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _status = 'Aggiornamento stato KYC...';
      });
    }
    try {
      final remote = await _registry.fetchKycSessionStatus(
        sessionId: sessionId,
      );
      await _saveRemoteKyc(remote);
      await _loadIdentity(attemptRecovery: false);
      if (mounted) setState(() => _status = _remoteStatusText(remote));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _status = 'Stato KYC non disponibile: $error';
      });
    }
  }

  Future<void> _saveRemoteKyc(Map<String, dynamic> remote) async {
    final sessionId = remote['sessionId']?.toString() ?? '';
    final provider = remote['provider']?.toString() ?? 'stripe_identity';
    final status = remote['status']?.toString() ?? 'unknown';
    if (sessionId.isNotEmpty) {
      await _identityStore.saveKycSession(
        sessionId: sessionId,
        provider: provider,
        status: status,
      );
    }
    await _identityStore.saveKycStatus(
      status,
      verifiedOutputs: remote['verifiedOutputs'] is Map
          ? Map<String, dynamic>.from(remote['verifiedOutputs'] as Map)
          : null,
    );
  }

  String _remoteStatusText(Map<String, dynamic> remote) {
    final status = remote['status']?.toString() ?? 'unknown';
    final lastError = remote['lastError'];
    final errorText = lastError == null
        ? ''
        : lastError is Map
            ? jsonEncode(lastError)
            : lastError.toString();
    if (status == 'verified') return 'Identita legale verificata da Stripe';
    if (status == 'processing') return 'Verifica Stripe in elaborazione';
    if (status == 'requires_input') {
      return errorText.isEmpty
          ? 'Stripe richiede il completamento della verifica'
          : 'Stripe richiede nuovi dati: $errorText';
    }
    return errorText.isEmpty ? 'Stato KYC: $status' : 'Stato KYC: $status\n$errorText';
  }

  Widget _row(String label, dynamic value) {
    final text = value?.toString() ?? '';
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 3),
          SelectableText(text, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Identita creator')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(
                _verified ? Icons.verified_user : Icons.badge_outlined,
                size: 72,
                color: _verified ? Colors.green : Colors.grey,
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _nameController,
                enabled: !_verified && !_loading,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Nome dichiarato',
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _loading || _verified ? null : _saveDeclaredName,
                child: const Text('SALVA NOME'),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _loading || _verified ? null : _startOrResumeKyc,
                icon: const Icon(Icons.verified_user),
                label: const Text('AVVIA O RIPRENDI KYC'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _loading ? null : _recoverKyc,
                icon: const Icon(Icons.cloud_download_outlined),
                label: const Text('RECUPERA KYC'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _loading || _sessionId.isEmpty
                    ? null
                    : () => _refreshKyc(),
                icon: const Icon(Icons.refresh),
                label: const Text('AGGIORNA STATO'),
              ),
              if (_loading) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
              const SizedBox(height: 16),
              SelectableText(_status, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              _row('Account tecnico', _creatorId),
              _row('Nome creator', _creatorName),
              _row('Impronta chiave dispositivo', _keyFingerprint),
              _row('Livello identita', _identity['identityAssuranceLevel']),
              _row('Identita legale', _identity['legalIdentityStatus']),
              _row('Nome legale verificato', _identity['verifiedLegalName']),
              _row('Paese verificato', _identity['verifiedLegalCountry']),
              _row('Sessione Stripe', _sessionId),
              _row('Stato KYC', _kycStatus),
              _row('Livello di fiducia', _identity['trustLevel']),
            ],
          ),
        ),
      ),
    );
  }
}
