import 'package:flutter/material.dart';

import 'hcv_identity.dart';

class IdentityPage extends StatefulWidget {
  const IdentityPage({super.key});

  @override
  State<IdentityPage> createState() => _IdentityPageState();
}

class _IdentityPageState extends State<IdentityPage> {
  final TextEditingController nameController = TextEditingController();

  String creatorId = "";
  String keyFingerprint = "";
  String privacyMode = "";
  String trustLevel = "LOCAL_KEY_VERIFIED";
  String status = "Caricamento identita...";

  @override
  void initState() {
    super.initState();
    loadIdentity();
  }

  Future<void> loadIdentity() async {
    final identity = await HCVIdentity().loadIdentity();

    setState(() {
      creatorId = identity["creatorId"]?.toString() ?? "";
      keyFingerprint =
          identity["devicePublicKeyFingerprint"]?.toString() ?? "";
      privacyMode = identity["privacyMode"]?.toString() ?? "";
      nameController.text =
          identity["creatorName"]?.toString() ?? "Local Creator";
      trustLevel = identity["trustLevel"]?.toString() ?? "LOCAL_KEY_VERIFIED";
      status = "Identita caricata";
    });
  }

  Future<void> saveIdentity() async {
    final name = nameController.text.trim();

    if (name.isEmpty) {
      setState(() {
        status = "Inserisci un nome creator";
      });
      return;
    }

    final identityStore = HCVIdentity();
    await identityStore.saveCreatorName(name);
    final identity = await identityStore.loadIdentity();

    setState(() {
      creatorId = identity["creatorId"]?.toString() ?? "";
      keyFingerprint =
          identity["devicePublicKeyFingerprint"]?.toString() ?? "";
      privacyMode = identity["privacyMode"]?.toString() ?? "";
      trustLevel = identity["trustLevel"]?.toString() ?? "LOCAL_KEY_VERIFIED";
      status = "Identita salvata";
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
            value.isEmpty ? "Non ancora generato" : value,
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
        title: const Text("Identita Creator"),
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
              const Text(
                "Identita SIGILLUM",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Questa identita usa una chiave del dispositivo. SIGILLUM non raccoglie il numero di serie del telefono.",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: "Nome creator",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: saveIdentity,
                child: const Text("SALVA IDENTITA"),
              ),
              const SizedBox(height: 24),
              Text(
                status,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              infoRow("Creator ID", creatorId),
              infoRow("Device Key Fingerprint", keyFingerprint),
              infoRow("Privacy Mode", privacyMode),
              infoRow("Trust Level", trustLevel),
            ],
          ),
        ),
      ),
    );
  }
}
