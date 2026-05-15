import 'package:flutter/foundation.dart';

class CameraService {
  static dynamic getCamera() {
    if (kIsWeb) {
      return "web";
    } else {
      return "native";
    }
  }
}