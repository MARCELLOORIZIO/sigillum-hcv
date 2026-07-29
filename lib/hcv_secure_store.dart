import 'dart:io';

import 'package:flutter/services.dart';

class HCVSecureStore {
  const HCVSecureStore._();

  static const MethodChannel _channel = MethodChannel('hcv.keystore');

  static Future<void> write(String key, String value) async {
    if (!Platform.isIOS && !Platform.isAndroid) {
      throw UnsupportedError(
        'Secure account storage is currently available on iOS and Android.',
      );
    }
    await _channel.invokeMethod<void>('setSecret', {
      'key': key,
      'value': value,
    });
  }

  static Future<String?> read(String key) async {
    if (!Platform.isIOS && !Platform.isAndroid) return null;
    return _channel.invokeMethod<String>('getSecret', {'key': key});
  }

  static Future<void> delete(String key) async {
    if (!Platform.isIOS && !Platform.isAndroid) return;
    await _channel.invokeMethod<void>('deleteSecret', {'key': key});
  }
}
