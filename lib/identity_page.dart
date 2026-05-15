import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class IdentityPage extends StatefulWidget {
  const IdentityPage({super.key});

  @override
  State<IdentityPage> createState() => _IdentityPageState();
}

class _IdentityPageState extends State<IdentityPage> {
  final TextEditingController nameController = TextEditingController();

  String creatorId = "";
  String deviceId = "";
  String trustLevel = "LOCAL_VERIFIED";
  String status = "Caricamento identità...";

  @override
  void initState() {
    super.initState();
    loadIdentity();
  }

  Future<void> loadIdentity() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      creatorId = prefs.getString("hcv_creator_id") ?? "";
      deviceId = prefs.getString("hcv_device_id") ?? "";
      nameController.text =
          prefs.getString("hcv_creator_name") ?? "Local Android Creator";
      trustLevel = "LOCAL_VERIFIED";
      status = "Identità caricata";
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

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("hcv_creator_name", name);

    setState(() {
      status = "Identità salvata";
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
        title: const Text("Identità Creator"),
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
                "Identità HCV",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                "Questa identità verrà inserita nei nuovi certificati HCV.",
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
                child: const Text("SALVA IDENTITÀ"),
              ),

              const SizedBox(height: 24),

              Text(
                status,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              infoRow("Creator ID", creatorId),
              infoRow("Device ID", deviceId),
              infoRow("Trust Level", trustLevel),
            ],
          ),
        ),
      ),
    );
  }
}