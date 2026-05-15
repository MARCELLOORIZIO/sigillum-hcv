import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

class HCVVerifier {

  // 🔐 HASH FUNCTION
  String _hash(String input) {
    return sha256.convert(utf8.encode(input)).toString();
  }

  // 📂 VERIFICA FILE .HCV
  Future<bool> verifyFile(String path) async {

    final file = File(path);

    if (!await file.exists()) {
      throw Exception("File .hcv non trovato");
    }

    final content = await file.readAsString();
    final data = jsonDecode(content);

    final chain = data["chain"] as List;

    String previousHash = "GENESIS";

    for (var item in chain) {

      // 🧠 ricostruisco evento SENZA hash
      final Map<String, dynamic> temp = Map.from(item);
      final originalHash = temp["hash"];

      temp.remove("hash");

      final computedHash = _hash(jsonEncode(temp));

      // ❌ se hash non coincide → file manomesso
      if (computedHash != originalHash) {
        return false;
      }

      // ❌ verifica collegamento chain
      if (temp["prev"] != previousHash) {
        return false;
      }

      previousHash = originalHash;
    }

    return true;
  }
}