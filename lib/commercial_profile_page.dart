import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      'otherDevice': 'Altro dispositivo',
      'lastSeen': 'Ultimo accesso',
      'fingerprint': 'Impronta',
      'revoke': 'REVOCA',
      'revokeTitle': 'Revoca dispositivo',
      'revokeBody': 'Questo dispositivo verrà disconnesso immediatamente e dovrà essere nuovamente autorizzato via email per accedere a SIGILLUM. Inserisci la password del tuo account per continuare.',
      'revoked': 'Dispositivo revocato.',
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
      'otherDevice': 'Other device',
      'lastSeen': 'Last access',
      'fingerprint': 'Fingerprint',
      'revoke': 'REVOKE',
      'revokeTitle': 'Revoke device',
      'revokeBody': 'This device will be signed out immediately and will require email approval before it can access SIGILLUM again. Enter your account password to continue.',
      'revoked': 'Device revoked.',
    },
  };

  static const Map<String, Map<String, String>> _extraCopy = {
    'es': {
      'title': 'Cuenta',
      'identity': 'Identidad',
      'verified': 'Verificada',
      'notVerified': 'No verificada',
      'subscription': 'Suscripción',
      'active': 'Activa',
      'inactive': 'Inactiva',
      'profile': 'Perfil',
      'name': 'Nombre',
      'email': 'Email',
      'language': 'Idioma',
      'save': 'GUARDAR PERFIL',
      'security': 'Seguridad',
      'devices': 'DISPOSITIVOS CONECTADOS',
      'password': 'CAMBIAR CONTRASEÑA',
      'manageSubscription': 'GESTIONAR SUSCRIPCIÓN',
      'privacy': 'Privacidad y condiciones',
      'legal': 'PRIVACIDAD, TÉRMINOS E INFORMACIÓN',
      'logout': 'CERRAR SESIÓN',
      'delete': 'ELIMINAR CUENTA',
      'currentPassword': 'Contraseña actual',
      'newPassword': 'Nueva contraseña',
      'cancel': 'CANCELAR',
      'confirm': 'CONFIRMAR',
      'deleteTitle': 'Eliminar cuenta',
      'deleteBody': 'Introduce tu contraseña para eliminar definitivamente la cuenta. Los registros técnicos de certificados ya emitidos pueden permanecer minimizados para preservar su verificabilidad.',
      'saved': 'Perfil actualizado.',
      'passwordChanged': 'Contraseña actualizada.',
      'noDevices': 'No hay dispositivos disponibles.',
      'thisDevice': 'Este dispositivo',
      'otherDevice': 'Otro dispositivo',
      'lastSeen': 'Último acceso',
      'fingerprint': 'Huella',
      'revoke': 'REVOCAR',
      'revokeTitle': 'Revocar dispositivo',
      'revokeBody': 'Este dispositivo cerrará la sesión inmediatamente y deberá volver a autorizarse por email antes de acceder de nuevo a SIGILLUM. Introduce la contraseña de tu cuenta para continuar.',
      'revoked': 'Dispositivo revocado.',
    },
    'ru': {
      'title': 'Аккаунт',
      'identity': 'Личность',
      'verified': 'Подтверждена',
      'notVerified': 'Не подтверждена',
      'subscription': 'Подписка',
      'active': 'Активна',
      'inactive': 'Неактивна',
      'profile': 'Профиль',
      'name': 'Имя',
      'email': 'Email',
      'language': 'Язык',
      'save': 'СОХРАНИТЬ ПРОФИЛЬ',
      'security': 'Безопасность',
      'devices': 'ПОДКЛЮЧЁННЫЕ УСТРОЙСТВА',
      'password': 'ИЗМЕНИТЬ ПАРОЛЬ',
      'manageSubscription': 'УПРАВЛЕНИЕ ПОДПИСКОЙ',
      'privacy': 'Конфиденциальность и условия',
      'legal': 'КОНФИДЕНЦИАЛЬНОСТЬ, УСЛОВИЯ И ИНФОРМАЦИЯ',
      'logout': 'ВЫЙТИ ИЗ АККАУНТА',
      'delete': 'УДАЛИТЬ АККАУНТ',
      'currentPassword': 'Текущий пароль',
      'newPassword': 'Новый пароль',
      'cancel': 'ОТМЕНА',
      'confirm': 'ПОДТВЕРДИТЬ',
      'deleteTitle': 'Удалить аккаунт',
      'deleteBody': 'Введите пароль, чтобы окончательно удалить аккаунт. Технические записи уже выпущенных сертификатов могут сохраняться в минимизированном виде для поддержания возможности проверки.',
      'saved': 'Профиль обновлён.',
      'passwordChanged': 'Пароль обновлён.',
      'noDevices': 'Нет доступных устройств.',
      'thisDevice': 'Это устройство',
      'otherDevice': 'Другое устройство',
      'lastSeen': 'Последний вход',
      'fingerprint': 'Отпечаток',
      'revoke': 'ОТОЗВАТЬ',
      'revokeTitle': 'Отозвать устройство',
      'revokeBody': 'Сеанс на этом устройстве будет немедленно завершён. Для нового доступа к SIGILLUM потребуется повторное подтверждение по email. Введите пароль аккаунта для продолжения.',
      'revoked': 'Устройство отозвано.',
    },
  };

  String _t(String key) =>
      (_copy[_languageCode] ??
          _extraCopy[_languageCode] ??
          _copy['en']!)[key] ??
      _copy['en']![key] ??
      key;

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
      final envelope = await _auth.updateProfile(
        creatorName: name,
        languageCode: _languageCode,
      );
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

      final selected = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (dialogContext) => AlertDialog(
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
                        leading: Icon(
                          current
                              ? Icons.phone_iphone_rounded
                              : Icons.devices_rounded,
                        ),
                        title: Text(
                          current ? _t('thisDevice') : _t('otherDevice'),
                        ),
                        subtitle: Text(
                          '${_t('lastSeen')}: ${_date(item['lastSeenAt']?.toString())}\n'
                          '${_t('fingerprint')}: ${_fingerprintTail(item['fingerprint'])}',
                        ),
                        trailing: current
                            ? null
                            : TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: SigillumTheme.danger,
                                ),
                                onPressed: () => Navigator.pop(dialogContext, item),
                                child: Text(_t('revoke')),
                              ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      if (selected == null || !mounted) return;
      if (selected['current'] == true) return;

      final fingerprint = selected['fingerprint']?.toString().trim() ?? '';
      if (fingerprint.isEmpty) return;

      final password = TextEditingController();
      final value = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(_t('revokeTitle')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_t('revokeBody')),
              const SizedBox(height: 10),
              Text(
                '${_t('fingerprint')}: ${_fingerprintTail(fingerprint)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
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
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(_t('cancel')),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: SigillumTheme.danger,
              ),
              onPressed: () => Navigator.pop(dialogContext, password.text),
              child: Text(_t('revoke')),
            ),
          ],
        ),
      );
      password.dispose();

      if (value == null || value.isEmpty) return;
      final response = await _auth.revokeDevice(
        deviceKeyFingerprint: fingerprint,
        password: value,
      );
      if (!mounted) return;
      final serverMessage = response['message']?.toString().trim() ?? '';
      setState(() {
        _message = serverMessage.isNotEmpty ? serverMessage : _t('revoked');
      });
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
      TextInput.finishAutofillContext(shouldSave: false);
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
            style: FilledButton.styleFrom(
              backgroundColor: SigillumTheme.danger,
            ),
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
      TextInput.finishAutofillContext(shouldSave: false);
      widget.onSessionInvalidated();
    });
  }

  String _fingerprintTail(dynamic raw) {
    final value = raw?.toString().trim() ?? '';
    if (value.isEmpty) return '—';
    final tail = value.length > 12 ? value.substring(value.length - 12) : value;
    return '…${tail.toUpperCase()}';
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

    final identityVerified =
        _account['kycStatus'] == 'verified' ||
        _account['legalIdentityVerified'] == true;
    final subscriptionActive =
        _billing['status'] == 'active' || _billing['status'] == 'grace';

    return Scaffold(
      backgroundColor: const Color(0xFFEAFBFF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(_t('title')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 34),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: SigillumTheme.panel,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: SigillumTheme.border),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12280D5F),
                  blurRadius: 22,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _account['creatorName']?.toString().isNotEmpty == true
                      ? _account['creatorName'].toString()
                      : 'SIGILLUM Creator',
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                  ),
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
                style: TextButton.styleFrom(
                  foregroundColor: SigillumTheme.danger,
                ),
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
        Icon(
          icon,
          size: 20,
          color: good ? SigillumTheme.verified : SigillumTheme.muted,
        ),
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
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: SigillumTheme.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10280D5F),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 13),
          ...children,
        ],
      ),
    );
  }
}
