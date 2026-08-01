import 'package:uuid/uuid.dart';

class HCVID {
  static final RegExp pattern = RegExp(
    r'HCV-[A-F0-9]{8,32}',
    caseSensitive: false,
  );
  static final RegExp _fullPattern = RegExp(
    r'^HCV-[A-F0-9]{8,32}$',
    caseSensitive: false,
  );

  static String generate() {
    final hex = const Uuid().v4().replaceAll('-', '').toUpperCase();
    return 'HCV-${hex.substring(0, 16)}';
  }

  static String? normalize(String value) {
    final normalized = value
        .trim()
        .toUpperCase()
        .replaceAll('\u2014', '-')
        .replaceAll('\u2013', '-')
        .replaceAll('HCV-ID:', 'HCV-')
        .replaceAll('HCV ID:', 'HCV-')
        .replaceAll('HCVID:', 'HCV-')
        .replaceAll('HCV_ID', 'HCV-')
        .replaceAll('HCV_', 'HCV-')
        .replaceAll(RegExp(r'\s+'), '');
    final match = pattern.firstMatch(normalized);
    return match?.group(0)?.toUpperCase();
  }

  static bool isValid(String value) {
    final normalized = normalize(value);
    return normalized != null && _fullPattern.hasMatch(normalized);
  }
}
