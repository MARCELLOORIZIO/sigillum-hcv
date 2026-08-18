import 'package:shared_preferences/shared_preferences.dart';

/// Stores only recently used Creator email addresses on this device.
/// Passwords and authentication tokens are never stored here.
class RecentAccountService {
  const RecentAccountService();

  static const _key = 'sigillum.recent.creator.emails.v1';
  static const _maxAccounts = 5;

  Future<List<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const <String>[];
    final seen = <String>{};
    final result = <String>[];
    for (final value in raw) {
      final email = value.trim().toLowerCase();
      if (email.isEmpty || !email.contains('@') || !seen.add(email)) continue;
      result.add(email);
      if (result.length >= _maxAccounts) break;
    }
    return result;
  }

  Future<List<String>> remember(String value) async {
    final email = value.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) return load();
    final current = await load();
    final updated = <String>[
      email,
      ...current.where((item) => item != email),
    ].take(_maxAccounts).toList(growable: false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, updated);
    return updated;
  }

  Future<List<String>> forget(String value) async {
    final email = value.trim().toLowerCase();
    final current = await load();
    final updated = current.where((item) => item != email).toList(growable: false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, updated);
    return updated;
  }
}
