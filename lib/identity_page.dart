import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'hcv_identity.dart';
import 'hcv_registry_service.dart';
import 'sigillum_localization.dart';

class IdentityPage extends StatefulWidget {
  const IdentityPage({
    super.key,
    this.languageCode = 'it',
  });

  final String languageCode;

  @override
  State<IdentityPage> createState() => _IdentityPageState();
}

class _IdentityPageState extends State<IdentityPage> {
  final TextEditingController nameController = TextEditingController();

  String creatorId = "";
  String keyFingerprint = "";
  String identityFingerprint = "";
  String identityAssuranceLevel = "";
  String legalIdentityStatus = "";
  String privacyMode = "";
  String kycSessionId = "";
  String kycStatus = "";
  String trustLevel = "LOCAL_KEY_VERIFIED";
  String status = "";

  String _t(String key) => SigillumCopy.t(widget.languageCode, key);

  @override
  void initState() {
    super.initState();
    status = _t('loadingTechnicalIdentity');
    loadIdentity();
  }

  Future<void> loadIdentity() async {
    final identity = await HCVIdentity().loadIdentity();

    setState(() {
      creatorId = identity["creatorId"]?.toString() ?? "";
      keyFingerprint = identity["devicePublicKeyFingerprint"]?.toString() ?? "";
      identityFingerprint = identity["identityFingerprint"]?.toString() ?? "";
      identityAssuranceLevel =
          identity["identityAssuranceLevel"]?.toString() ?? "";
      legalIdentityStatus = identity["legalIdentityStatus"]?.toString() ?? "";
      privacyMode = identity["privacyMode"]?.toString() ?? "";
      kycSessionId = identity["kycSessionId"]?.toString() ?? "";
      kycStatus = identity["kycStatus"]?.toString() ?? "";
      nameController.text =
          identity["creatorName"]?.toString() ?? "Local Creator";
      trustLevel = identity["trustLevel"]?.toString() ?? "LOCAL_KEY_VERIFIED";
      status = _t('technicalIdentityLoaded');
    });
  }

  Future<void> saveIdentity() async {
    final name = nameController.text.trim();

    if (name.isEmpty) {
      setState(() {
        status = _t('enterDeclaredName');
      });
      return;
    }

    final identityStore = HCVIdentity();
    await identityStore.saveCreatorName(name);
    final identity = await identityStore.loadIdentity();

    setState(() {
      creatorId = identity["creatorId"]?.toString() ?? "";
      keyFingerprint = identity["devicePublicKeyFingerprint"]?.toString() ?? "";
      identityFingerprint = identity["identityFingerprint"]?.toString() ?? "";
      identityAssuranceLevel =
          identity["identityAssuranceLevel"]?.toString() ?? "";
      legalIdentityStatus = identity["legalIdentityStatus"]?.toString() ?? "";
      privacyMode = identity["privacyMode"]?.toString() ?? "";
      kycSessionId = identity["kycSessionId"]?.toString() ?? "";
      kycStatus = identity["kycStatus"]?.toString() ?? "";
      trustLevel = identity["trustLevel"]?.toString() ?? "LOCAL_KEY_VERIFIED";
      status = _t('declaredNameSaved');
    });
  }

  Future<void> startKyc() async {
    final name = nameController.text.trim();

    setState(() {
      status = _t('kycStarting');
    });

    try {
      final session = await const HCVRegistryService().startKycSession(
        creatorId: creatorId,
        creatorName: name.isEmpty ? 'Local Creator' : name,
      );
      final url = session['url']?.toString() ?? '';
      final provider = session['provider']?.toString() ?? 'stripe_identity';
      final sessionId = session['sessionId']?.toString() ?? '';
      final remoteStatus = session['status']?.toString() ?? 'created';

      if (sessionId.isNotEmpty) {
        await HCVIdentity().saveKycSession(
          sessionId: sessionId,
          provider: provider,
          status: remoteStatus,
        );
      }

      setState(() {
        kycSessionId = sessionId;
        kycStatus = remoteStatus;
        status = url.isEmpty ? _t('kycConfiguredNoUrl') : _t('kycOpening');
      });

      if (url.isNotEmpty) {
        final opened = await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );
        if (!opened) {
          setState(() {
            status = '${_t('kycLinkReady')}\n$url';
          });
        }
      }
    } catch (err) {
      setState(() {
        status = '${_t('kycNotAvailable')}\n$err';
      });
    }
  }

  Future<void> refreshKycStatus() async {
    if (kycSessionId.isEmpty) {
      setState(() {
        status = _t('kycNoSession');
      });
      return;
    }

    setState(() {
      status = _t('kycRefreshing');
    });

    try {
      final remote = await const HCVRegistryService().fetchKycSessionStatus(
        sessionId: kycSessionId,
      );
      final remoteStatus = remote['status']?.toString() ?? 'unknown';
      await HCVIdentity().saveKycStatus(remoteStatus);
      final identity = await HCVIdentity().loadIdentity();

      setState(() {
        identityAssuranceLevel =
            identity["identityAssuranceLevel"]?.toString() ?? "";
        legalIdentityStatus = identity["legalIdentityStatus"]?.toString() ?? "";
        trustLevel = identity["trustLevel"]?.toString() ?? "LOCAL_KEY_VERIFIED";
        kycStatus = remoteStatus;
        status = remoteStatus == 'verified'
            ? _t('kycVerified')
            : '${_t('kycStatus')}: $remoteStatus';
      });
    } catch (err) {
      setState(() {
        status = '${_t('kycStatusUnavailable')}\n$err';
      });
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  Widget infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value.isEmpty ? _t('notGeneratedYet') : value,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('technicalIdentityTitle')),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(
                Icons.badge,
                size: 72,
                color: Colors.green,
              ),
              const SizedBox(height: 20),
              Text(
                _t('technicalIdentityHeading'),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _t('technicalIdentityBody'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: _t('declaredName'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: saveIdentity,
                child: Text(_t('saveName')),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: startKyc,
                icon: const Icon(Icons.verified_user_outlined),
                label: Text(_t('startKyc')),
              ),
              const SizedBox(height: 8),
              Text(
                _t('kycExplanation'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: refreshKycStatus,
                icon: const Icon(Icons.refresh),
                label: Text(_t('refreshKyc')),
              ),
              const SizedBox(height: 24),
              SelectableText(
                status,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              infoRow(_t('technicalCreatorId'), creatorId),
              infoRow(_t('deviceKeyFingerprint'), keyFingerprint),
              infoRow(_t('technicalIdentityFingerprint'), identityFingerprint),
              infoRow(_t('identityAssurance'), identityAssuranceLevel),
              infoRow(_t('legalIdentity'), legalIdentityStatus),
              infoRow(_t('kycStatusLabel'), kycStatus),
              infoRow(_t('privacy'), privacyMode),
              infoRow(_t('technicalProof'), trustLevel),
            ],
          ),
        ),
      ),
    );
  }
}
