import 'package:flutter/services.dart';

class HCVKeystoreSigner {
  static const MethodChannel _channel = MethodChannel('hcv.keystore');

  static Future<String> sign(String canonicalJson) async {
    final result = await _channel.invokeMethod<String>(
      'sign',
      {
        'data': canonicalJson,
      },
    );

    if (result == null || result.isEmpty) {
      throw Exception('Android Keystore signature failed');
    }

    return result;
  }

  static Future<Map<String, dynamic>> getPublicKey() async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'getPublicKey',
    );

    if (result == null) {
      throw Exception('Android Keystore public key not available');
    }

    return {
      'modulus': result['modulus'],
      'exponent': result['exponent'],
    };
  }
}
