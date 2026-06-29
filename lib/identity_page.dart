import 'package:flutter/material.dart';

import 'hcv_identity.dart';
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
      trustLevel = identity["trustLevel"]?.toString() ?? "LOCAL_KEY_VERIFIED";
      status = _t('declaredNameSaved');
    });
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
                style: TextStyle(
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
              const SizedBox(height: 24),
              Text(
                status,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              infoRow(_t('technicalCreatorId'), creatorId),
              infoRow(_t('deviceKeyFingerprint'), keyFingerprint),
              infoRow(_t('technicalIdentityFingerprint'), identityFingerprint),
              infoRow(_t('identityAssurance'), identityAssuranceLevel),
              infoRow(_t('legalIdentity'), legalIdentityStatus),
              infoRow(_t('privacy'), privacyMode),
              infoRow(_t('technicalProof'), trustLevel),
            ],
          ),
        ),
      ),
    );
  }
}
