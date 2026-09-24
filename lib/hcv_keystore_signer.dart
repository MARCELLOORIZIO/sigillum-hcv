import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

class HCVKeystoreSigner {
  static const MethodChannel _channel = MethodChannel('hcv.keystore');

  static Future<String> sign(String canonicalJson) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      final bytes = utf8.encode('LOCAL_DEV_SIGNATURE:$canonicalJson');
      return sha256.convert(bytes).toString();
    }

    final result = await _channel.invokeMethod<String>(
      'sign',
      {
        'data': canonicalJson,
      },
    );

    if (result == null || result.isEmpty) {
      throw Exception('Keystore signature failed');
    }

    return result;
  }

  static Future<Map<String, dynamic>> getPublicKey() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return {
        'modulus': 'LOCAL_DEV_PUBLIC_KEY',
        'exponent': 'LOCAL_DEV',
      };
    }

    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'getPublicKey',
    );

    if (result == null) {
      throw Exception('Keystore public key not available');
    }

    return {
      'modulus': result['modulus'],
      'exponent': result['exponent'],
    };
  }
}
