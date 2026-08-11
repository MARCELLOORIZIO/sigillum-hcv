import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'commercial_account_service.dart';
import 'hcv_auth_service.dart';
import 'legal_info_page.dart';
import 'sigillum_localization.dart';
import 'sigillum_theme.dart';

class CommercialProfilePage extends StatefulWidget {
  const CommercialProfilePage({
    super.key,
    required this.languageCode,
    required this.onLanguageChanged,
    required this.onSessionInvalidated,
  });

  final String languageCode;
  final Future<void> Function(String code) onLanguageChanged;
  final VoidCallback onSessionInvalidated;

  @override
  State<CommercialProfilePage> createState() => _CommercialProfilePageState();
}

class _CommercialProfilePageState extends State<CommercialProfilePage> {
  final HCVAuthService _auth = const HCVAuthService();
  final CommercialAccountService _commercial = const CommercialAccountService();
  final TextEditingController _name = TextEditingController();

  Map<String, dynamic> _account = const {};
  Map<String, dynamic> _billing = const {};
  bool _loading = true;
  bool _busy = false;
  String _message = '';
  late String _languageCode;

  static const Map<String, Map<String, String>> _copy = {
    'it': {
      'title': 'Account',
      'identity': 'Identità',
      'verified': 'Verificata',
      'notVerified': 'Non verificata',
      'subscription': 'Abbonamento',
      'active': 'Attivo',
      'inactive': 'Non attivo',
      'profile': 'Profilo',
      'name': 'Nome',
      'email': 'Email',
      'language': 'Lingua',
      'save': 'SALVA PROFILO',
      'security': 'Sicurezza',
      'devices': 'DISPOSITIVI COLLEGATI',
      'password': 'CAMBIA PASSWORD',
      'manageSubscription': 'GESTISCI ABBONAMENTO',
      'privacy': 'Privacy e condizioni',
      'legal': 'PRIVACY, TERMINI E INFORMAZIONI',
      'logout': 'ESCI DALL’ACCOUNT',
      'delete': 'ELIMINA ACCOUNT',
      'currentPassword': 'Password attuale',
      'newPassword': 'Nuova password',
      'cancel': 'ANNULLA',
      'confirm': 'CONFERMA',
      'deleteTitle': 'Elimina account',
      'deleteBody': 'Inserisci la password per eliminare definitivamente l’account. I record tecnici dei certificati già emessi possono restare disponibili in forma minimizzata per preservarne la verificabilità.',
      'saved': 'Profilo aggiornato.',
      'passwordChanged': 'Password aggiornata.',
      'noDevices': 'Nessun dispositivo disponibile.',
      'thisDevice': 'Questo dispositivo',
      'lastSeen': 'Ultimo accesso',
    },
    'en': {
      'title': 'Account',
      'identity': 'Identity',
      'verified': 'Verified',
      'notVerified': 'Not verified',
      'subscription': 'Subscription',
      'active': 'Active',
      'inactive': 'Inactive',
      'profile': 'Profile',
      'name': 'Name',
      'email': 'Email',
      'language': 'Language',
      'save': 'SAVE PROFILE',
      'security': 'Security',
      'devices': 'CONNECTED DEVICES',
      'password': 'CHANGE PASSWORD',
      'manageSubscription': 'MANAGE SUBSCRIPTION',
      'privacy': 'Privacy and terms',
      'legal': 'PRIVACY, TERMS AND INFORMATION',
      'logout': 'LOG OUT',
      'delete': 'DELETE ACCOUNT',
      'currentPassword': 'Current password',
      'newPassword': 'New password',
      'cancel': 'CANCEL',
      'confirm': 'CONFIRM',
      'deleteTitle': 'Delete account',
      'deleteBody': 'Enter your password to permanently delete the account. Technical records for already-issued certificates may remain in minimized form to preserve verification.',
      'saved': 'Profile updated.',
      'passwordChanged': 'Password updated.',
      'noDevices': 'No devices available.',
      'thisDevice': 'This device',
      'lastSeen': 'Last access',
    },
  };

  String _t(String key) =>
      (_copy[_languageCode] ?? _copy['en']!)[key] ?? _copy['en']![key] ?? key;

  @override
  void initState() {
    super.initState();
    _languageCode = widget.languageCode;
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final envelope = await _auth.restoreSession();
      if (envelope == null) {
        widget.onSessionInvalidated();
        return;
      }
      final raw = envelope['account'];
      final billing = await _commercial.billingStatus();
      if (!mounted) return;
      setState(() {
        _account = raw is Map ? Map<String, dynamic>.from(raw) : const {};
        _billing = billing;
        _name.text = _account['creatorName']?.toString() ?? '';
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = error.toString();
      });
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = '';
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _message = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    await _run(() async {
      final envelope = await _auth.updateProfile(creatorName: name);
      final raw = envelope['account'];
      if (!mounted) return;
      setState(() {
        if (raw is Map) _account = Map<String, dynamic>.from(raw);
        _message = _t('saved');
      });
    });
  }

  Future<void> _changeLanguage(String? code) async {
    if (code == null || code == _languageCode) return;
    await widget.onLanguageChanged(code);
    if (mounted) setState(() => _languageCode = code);
  }

  Future<void> _showDevices() async {
    await _run(() async {
      final devices = await _auth.listDevices();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(_t('devices')),
          content: SizedBox(
            width: double.maxFinite,
            child: devices.isEmpty
                ? Text(_t('noDevices'))
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: devices.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final item = devices[index];
                      final current = item['current'] == true;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(current
                            ? Icons.phone_iphone_rounded
                            : Icons.devices_rounded),
                        title: Text(current
                            ? _t('thisDevice')
                            : 'Dispositivo ${index + 1}'),
                        subtitle: Text(
                          '${_t('lastSeen')}: ${_date(item['lastSeenAt']?.toString())}',
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _changePassword() async {
    final current = TextEditingController();
    final next = TextEditingController();
    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('password')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: current,
              obscureText: true,
              decoration: InputDecoration(labelText: _t('currentPassword')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: next,
              obscureText: true,
              decoration: InputDecoration(labelText: _t('newPassword')),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, [current.text, next.text]),
            child: Text(_t('confirm')),
          ),
        ],
      ),
    );
    current.dispose();
    next.dispose();
    if (result == null || result.length != 2 || result[1].length < 12) return;
    await _run(() async {
      await _auth.changePassword(
        currentPassword: result[0],
        newPassword: result[1],
      );
      if (mounted) setState(() => _message = _t('passwordChanged'));
    });
  }

  Future<void> _manageSubscription() async {
    final uri = Uri.parse('https://apps.apple.com/account/subscriptions');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      setState(() => _message = 'Impossibile aprire la gestione abbonamento.');
    }
  }

  Future<void> _logout() async {
    await _run(() async {
      await _auth.logout();
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSessionInvalidated();
    });
  }

  Future<void> _deleteAccount() async {
    final password = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('deleteTitle')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_t('deleteBody')),
            const SizedBox(height: 12),
            TextField(
              controller: password,
              obscureText: true,
              decoration: InputDecoration(labelText: _t('currentPassword')),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_t('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: SigillumTheme.danger),
            onPressed: () => Navigator.pop(context, password.text),
            child: Text(_t('delete')),
          ),
        ],
      ),
    );
    password.dispose();
    if (value == null || value.isEmpty) return;
    await _run(() async {
      await _auth.deleteAccount(password: value);
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSessionInvalidated();
    });
  }

  String _date(String? raw) {
    final value = DateTime.tryParse(raw ?? '')?.toLocal();
    if (value == null) return '—';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year} ${two(value.hour)}:${two(value.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(_t('title'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final identityVerified = _account['kycStatus'] == 'verified' ||
        _account['legalIdentityVerified'] == true;
    final subscriptionActive = _billing['status'] == 'active' ||
        _billing['status'] == 'development_allowed';

    return Scaffold(
      appBar: AppBar(title: Text(_t('title'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 34),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: SigillumTheme.panel,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _account['creatorName']?.toString().isNotEmpty == true
                      ? _account['creatorName'].toString()
                      : 'SIGILLUM Creator',
                  style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  _account['email']?.toString() ?? '',
                  style: const TextStyle(color: SigillumTheme.muted),
                ),
                const SizedBox(height: 14),
                _StatusRow(
                  icon: Icons.badge_outlined,
                  label: _t('identity'),
                  value: identityVerified ? _t('verified') : _t('notVerified'),
                  good: identityVerified,
                ),
                const SizedBox(height: 8),
                _StatusRow(
                  icon: Icons.workspace_premium_outlined,
                  label: _t('subscription'),
                  value: subscriptionActive ? _t('active') : _t('inactive'),
                  good: subscriptionActive,
                ),
              ],
            ),
          ),
          if (_busy) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          if (_message.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              _message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: SigillumTheme.accent),
            ),
          ],
          const SizedBox(height: 18),
          _Section(
            title: _t('profile'),
            children: [
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: _t('name'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _languageCode,
                decoration: InputDecoration(
                  labelText: _t('language'),
                  border: const OutlineInputBorder(),
                ),
                items: [
                  for (final language in SigillumCopy.languages)
                    DropdownMenuItem(
                      value: language.code,
                      child: Text(language.name),
                    ),
                ],
                onChanged: _busy ? null : _changeLanguage,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _busy ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: Text(_t('save')),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Section(
            title: _t('security'),
            children: [
              OutlinedButton.icon(
                onPressed: _busy ? null : _showDevices,
                icon: const Icon(Icons.devices_outlined),
                label: Text(_t('devices')),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _busy ? null : _changePassword,
                icon: const Icon(Icons.password_outlined),
                label: Text(_t('password')),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _manageSubscription,
                icon: const Icon(Icons.workspace_premium_outlined),
                label: Text(_t('manageSubscription')),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Section(
            title: _t('privacy'),
            children: [
              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LegalInfoPage(languageCode: _languageCode),
                  ),
                ),
                icon: const Icon(Icons.privacy_tip_outlined),
                label: Text(_t('legal')),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _busy ? null : _logout,
                icon: const Icon(Icons.logout_outlined),
                label: Text(_t('logout')),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: _busy ? null : _deleteAccount,
                icon: const Icon(Icons.delete_forever_outlined),
                label: Text(_t('delete')),
                style: TextButton.styleFrom(foregroundColor: SigillumTheme.danger),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.good,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool good;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: good ? SigillumTheme.verified : SigillumTheme.muted),
        const SizedBox(width: 9),
        Expanded(child: Text(label)),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: good ? SigillumTheme.verified : SigillumTheme.muted,
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SigillumTheme.panel,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 13),
          ...children,
        ],
      ),
    );
  }
}
