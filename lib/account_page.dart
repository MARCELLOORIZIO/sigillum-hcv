import 'package:flutter/material.dart';

import 'hcv_auth_service.dart';
import 'hcv_identity.dart';
import 'identity_page.dart';
import 'legal_info_page.dart';
import 'sigillum_localization.dart';
import 'sigillum_theme.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({
    super.key,
    required this.languageCode,
    required this.onLanguageChanged,
  });

  final String languageCode;
  final Future<void> Function(String code) onLanguageChanged;

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final HCVAuthService _auth = const HCVAuthService();

  Map<String, dynamic> _identity = const {};
  Map<String, dynamic> _account = const {};
  late String _languageCode;
  String _sessionExpiresAt = '';
  bool _loading = true;
  bool _busy = false;
  bool _obscurePassword = true;
  String? _error;

  static const Map<String, Map<String, String>> _copy = {
    'it': {
      'title': 'Account',
      'profile': 'Profilo',
      'declaredName': 'Nome dichiarato',
      'save': 'SALVA MODIFICHE',
      'saved': 'Profilo aggiornato',
      'language': 'Lingua',
      'identity': 'Identità e verifica',
      'verifiedIdentity': 'Identità legale verificata',
      'creatorId': 'ID tecnico creator',
      'kycStatus': 'Stato KYC',
      'deviceKey': 'Chiave dispositivo',
      'manageIdentity': 'GESTISCI IDENTITÀ E KYC',
      'security': 'Sicurezza e accesso',
      'session': 'Sessione online',
      'active': 'Attiva',
      'notActive': 'Non attiva',
      'email': 'Email',
      'password': 'Password',
      'passwordHint': 'Almeno 12 caratteri',
      'createAccount': 'CREA ACCOUNT',
      'login': 'ACCEDI',
      'logout': 'LOGOUT',
      'logoutAll': 'LOGOUT DA TUTTI I DISPOSITIVI',
      'changePassword': 'CAMBIA PASSWORD',
      'devices': 'DISPOSITIVI COLLEGATI',
      'deviceCount': 'Dispositivi',
      'sessionExpires': 'Scadenza sessione',
      'accessExplanation':
          'L’accesso collega il profilo online alla chiave sicura di questo dispositivo. Il token di sessione è custodito nel Keychain o nel Keystore.',
      'privacy': 'Privacy e dati',
      'deleteAccount': 'ELIMINA ACCOUNT E DATI',
      'deleteInfo':
          'L’eliminazione rimuove account, sessioni, dispositivi e collegamenti KYC. I certificati HCV già firmati restano immutabili e verificabili.',
      'deleteConfirmTitle': 'Elimina account',
      'deleteConfirmBody':
          'Inserisci la password per eliminare definitivamente l’account. L’operazione non può essere annullata.',
      'cancel': 'ANNULLA',
      'confirmDelete': 'ELIMINA',
      'support': 'SUPPORTO E PRIVACY',
      'loading': 'Caricamento account...',
      'loadFailed': 'Impossibile caricare i dati account.',
      'nameRequired': 'Inserisci un nome dichiarato.',
      'emailRequired': 'Inserisci un indirizzo email valido.',
      'passwordRequired': 'La password deve contenere almeno 12 caratteri.',
      'localProfile': 'Profilo locale collegato a questo dispositivo',
      'registered': 'Account creato e sessione attivata.',
      'loggedIn': 'Accesso completato.',
      'loggedOut': 'Logout completato.',
      'deleted': 'Account e dati personali eliminati.',
      'currentPassword': 'Password attuale',
      'newPassword': 'Nuova password',
      'passwordChanged': 'Password aggiornata. Le altre sessioni sono state revocate.',
      'noDevices': 'Nessun dispositivo disponibile.',
      'currentDevice': 'Questo dispositivo',
      'lastSeen': 'Ultimo accesso',
      'loginToDelete': 'Accedi per eliminare l’account online.',
    },
    'en': {
      'title': 'Account',
      'profile': 'Profile',
      'declaredName': 'Declared name',
      'save': 'SAVE CHANGES',
      'saved': 'Profile updated',
      'language': 'Language',
      'identity': 'Identity and verification',
      'verifiedIdentity': 'Verified legal identity',
      'creatorId': 'Technical creator ID',
      'kycStatus': 'KYC status',
      'deviceKey': 'Device key',
      'manageIdentity': 'MANAGE IDENTITY AND KYC',
      'security': 'Security and access',
      'session': 'Online session',
      'active': 'Active',
      'notActive': 'Not active',
      'email': 'Email',
      'password': 'Password',
      'passwordHint': 'At least 12 characters',
      'createAccount': 'CREATE ACCOUNT',
      'login': 'LOG IN',
      'logout': 'LOG OUT',
      'logoutAll': 'LOG OUT ALL DEVICES',
      'changePassword': 'CHANGE PASSWORD',
      'devices': 'CONNECTED DEVICES',
      'deviceCount': 'Devices',
      'sessionExpires': 'Session expires',
      'accessExplanation':
          'Access links the online profile to this device secure key. The session token is stored in Keychain or Keystore.',
      'privacy': 'Privacy and data',
      'deleteAccount': 'DELETE ACCOUNT AND DATA',
      'deleteInfo':
          'Deletion removes the account, sessions, devices and KYC links. Existing signed HCV certificates remain immutable and verifiable.',
      'deleteConfirmTitle': 'Delete account',
      'deleteConfirmBody':
          'Enter your password to permanently delete the account. This cannot be undone.',
      'cancel': 'CANCEL',
      'confirmDelete': 'DELETE',
      'support': 'SUPPORT AND PRIVACY',
      'loading': 'Loading account...',
      'loadFailed': 'Unable to load account data.',
      'nameRequired': 'Enter a declared name.',
      'emailRequired': 'Enter a valid email address.',
      'passwordRequired': 'The password must contain at least 12 characters.',
      'localProfile': 'Local profile linked to this device',
      'registered': 'Account created and session activated.',
      'loggedIn': 'Login completed.',
      'loggedOut': 'Logout completed.',
      'deleted': 'Account and personal data deleted.',
      'currentPassword': 'Current password',
      'newPassword': 'New password',
      'passwordChanged': 'Password updated. Other sessions were revoked.',
      'noDevices': 'No devices available.',
      'currentDevice': 'This device',
      'lastSeen': 'Last access',
      'loginToDelete': 'Log in to delete the online account.',
    },
    'es': {
      'title': 'Cuenta',
      'profile': 'Perfil',
      'declaredName': 'Nombre declarado',
      'save': 'GUARDAR CAMBIOS',
      'saved': 'Perfil actualizado',
      'language': 'Idioma',
      'identity': 'Identidad y verificación',
      'verifiedIdentity': 'Identidad legal verificada',
      'creatorId': 'ID técnico del creador',
      'kycStatus': 'Estado KYC',
      'deviceKey': 'Clave del dispositivo',
      'manageIdentity': 'GESTIONAR IDENTIDAD Y KYC',
      'security': 'Seguridad y acceso',
      'session': 'Sesión en línea',
      'active': 'Activa',
      'notActive': 'No activa',
      'email': 'Correo electrónico',
      'password': 'Contraseña',
      'passwordHint': 'Al menos 12 caracteres',
      'createAccount': 'CREAR CUENTA',
      'login': 'ACCEDER',
      'logout': 'CERRAR SESIÓN',
      'logoutAll': 'CERRAR TODAS LAS SESIONES',
      'changePassword': 'CAMBIAR CONTRASEÑA',
      'devices': 'DISPOSITIVOS CONECTADOS',
      'deviceCount': 'Dispositivos',
      'sessionExpires': 'La sesión vence',
      'accessExplanation':
          'El acceso vincula el perfil en línea con la clave segura del dispositivo. El token se guarda en Keychain o Keystore.',
      'privacy': 'Privacidad y datos',
      'deleteAccount': 'ELIMINAR CUENTA Y DATOS',
      'deleteInfo':
          'La eliminación borra cuenta, sesiones, dispositivos y vínculos KYC. Los certificados HCV firmados siguen siendo verificables.',
      'deleteConfirmTitle': 'Eliminar cuenta',
      'deleteConfirmBody':
          'Introduce la contraseña para eliminar definitivamente la cuenta.',
      'cancel': 'CANCELAR',
      'confirmDelete': 'ELIMINAR',
      'support': 'SOPORTE Y PRIVACIDAD',
      'loading': 'Cargando cuenta...',
      'loadFailed': 'No se pueden cargar los datos.',
      'nameRequired': 'Introduce un nombre.',
      'emailRequired': 'Introduce un correo válido.',
      'passwordRequired': 'La contraseña debe tener al menos 12 caracteres.',
      'localProfile': 'Perfil local vinculado al dispositivo',
      'registered': 'Cuenta creada y sesión activada.',
      'loggedIn': 'Acceso completado.',
      'loggedOut': 'Sesión cerrada.',
      'deleted': 'Cuenta y datos eliminados.',
      'currentPassword': 'Contraseña actual',
      'newPassword': 'Nueva contraseña',
      'passwordChanged': 'Contraseña actualizada.',
      'noDevices': 'No hay dispositivos.',
      'currentDevice': 'Este dispositivo',
      'lastSeen': 'Último acceso',
      'loginToDelete': 'Accede para eliminar la cuenta.',
    },
    'ru': {
      'title': 'Аккаунт',
      'profile': 'Профиль',
      'declaredName': 'Указанное имя',
      'save': 'СОХРАНИТЬ',
      'saved': 'Профиль обновлен',
      'language': 'Язык',
      'identity': 'Личность и проверка',
      'verifiedIdentity': 'Юридическая личность подтверждена',
      'creatorId': 'Технический ID автора',
      'kycStatus': 'Статус KYC',
      'deviceKey': 'Ключ устройства',
      'manageIdentity': 'УПРАВЛЕНИЕ ЛИЧНОСТЬЮ И KYC',
      'security': 'Безопасность и доступ',
      'session': 'Онлайн-сессия',
      'active': 'Активна',
      'notActive': 'Не активна',
      'email': 'Email',
      'password': 'Пароль',
      'passwordHint': 'Не менее 12 символов',
      'createAccount': 'СОЗДАТЬ АККАУНТ',
      'login': 'ВОЙТИ',
      'logout': 'ВЫЙТИ',
      'logoutAll': 'ВЫЙТИ НА ВСЕХ УСТРОЙСТВАХ',
      'changePassword': 'ИЗМЕНИТЬ ПАРОЛЬ',
      'devices': 'ПОДКЛЮЧЕННЫЕ УСТРОЙСТВА',
      'deviceCount': 'Устройства',
      'sessionExpires': 'Срок сессии',
      'accessExplanation':
          'Вход связывает онлайн-профиль с защищенным ключом устройства. Токен хранится в Keychain или Keystore.',
      'privacy': 'Конфиденциальность и данные',
      'deleteAccount': 'УДАЛИТЬ АККАУНТ И ДАННЫЕ',
      'deleteInfo':
          'Удаляются аккаунт, сессии, устройства и связи KYC. Подписанные сертификаты HCV остаются проверяемыми.',
      'deleteConfirmTitle': 'Удалить аккаунт',
      'deleteConfirmBody': 'Введите пароль для окончательного удаления.',
      'cancel': 'ОТМЕНА',
      'confirmDelete': 'УДАЛИТЬ',
      'support': 'ПОДДЕРЖКА И КОНФИДЕНЦИАЛЬНОСТЬ',
      'loading': 'Загрузка аккаунта...',
      'loadFailed': 'Не удалось загрузить данные.',
      'nameRequired': 'Введите имя.',
      'emailRequired': 'Введите корректный email.',
      'passwordRequired': 'Пароль должен содержать не менее 12 символов.',
      'localProfile': 'Локальный профиль устройства',
      'registered': 'Аккаунт создан, сессия активна.',
      'loggedIn': 'Вход выполнен.',
      'loggedOut': 'Выход выполнен.',
      'deleted': 'Аккаунт и данные удалены.',
      'currentPassword': 'Текущий пароль',
      'newPassword': 'Новый пароль',
      'passwordChanged': 'Пароль обновлен.',
      'noDevices': 'Нет доступных устройств.',
      'currentDevice': 'Это устройство',
      'lastSeen': 'Последний доступ',
      'loginToDelete': 'Войдите, чтобы удалить аккаунт.',
    },
  };

  String _t(String key) =>
      (_copy[_languageCode] ?? _copy['en']!)[key] ?? _copy['en']![key] ?? key;

  bool get _signedIn => _account.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _languageCode = widget.languageCode;
    _loadAccount();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadAccount() async {
    try {
      final identity = await HCVIdentity().loadIdentity();
      Map<String, dynamic>? envelope;
      String? sessionError;
      try {
        envelope = await _auth.restoreSession();
      } on HCVAuthException catch (error) {
        sessionError = error.message;
      }
      if (!mounted) return;
      final account = envelope?['account'];
      final accountMap = account is Map
          ? Map<String, dynamic>.from(account)
          : <String, dynamic>{};
      setState(() {
        _identity = identity;
        _account = accountMap;
        _sessionExpiresAt = envelope?['expiresAt']?.toString() ?? '';
        _nameController.text = accountMap['creatorName']?.toString() ??
            identity['creatorName']?.toString() ??
            '';
        if (accountMap.isNotEmpty) {
          _emailController.text = accountMap['email']?.toString() ?? '';
        }
        _loading = false;
        _error = sessionError;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().isEmpty ? _t('loadFailed') : error.toString();
      });
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on HCVAuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _validateCredentials({bool requireName = false}) {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (!email.contains('@') || !email.contains('.')) {
      _showMessage(_t('emailRequired'));
      return false;
    }
    if (password.length < 12) {
      _showMessage(_t('passwordRequired'));
      return false;
    }
    if (requireName && _nameController.text.trim().isEmpty) {
      _showMessage(_t('nameRequired'));
      return false;
    }
    return true;
  }

  Future<void> _register() async {
    if (!_validateCredentials(requireName: true)) return;
    await _run(() async {
      final envelope = await _auth.register(
        email: _emailController.text,
        password: _passwordController.text,
        creatorName: _nameController.text,
      );
      await HCVIdentity().saveCreatorName(_nameController.text.trim());
      _applyEnvelope(envelope);
      _passwordController.clear();
      _showMessage(_t('registered'));
    });
  }

  Future<void> _login() async {
    if (!_validateCredentials()) return;
    await _run(() async {
      final envelope = await _auth.login(
        email: _emailController.text,
        password: _passwordController.text,
      );
      _applyEnvelope(envelope);
      final serverName = _account['creatorName']?.toString() ?? '';
      if (serverName.isNotEmpty) {
        await HCVIdentity().saveCreatorName(serverName);
        _nameController.text = serverName;
      }
      _passwordController.clear();
      _showMessage(_t('loggedIn'));
    });
  }

  void _applyEnvelope(Map<String, dynamic> envelope) {
    final raw = envelope['account'];
    final account = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    if (!mounted) return;
    setState(() {
      _account = account;
      _sessionExpiresAt = envelope['expiresAt']?.toString() ?? '';
      _emailController.text = account['email']?.toString() ?? '';
    });
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showMessage(_t('nameRequired'));
      return;
    }
    await _run(() async {
      if (_signedIn) {
        final envelope = await _auth.updateProfile(creatorName: name);
        _applyEnvelope(envelope);
      }
      await HCVIdentity().saveCreatorName(name);
      final identity = await HCVIdentity().loadIdentity();
      if (mounted) setState(() => _identity = identity);
      _showMessage(_t('saved'));
    });
  }

  Future<void> _changeLanguage(String? code) async {
    if (code == null || code == _languageCode) return;
    await widget.onLanguageChanged(code);
    if (!mounted) return;
    setState(() => _languageCode = code);
  }

  Future<void> _logout({bool allDevices = false}) async {
    await _run(() async {
      await _auth.logout(allDevices: allDevices);
      if (!mounted) return;
      setState(() {
        _account = const {};
        _sessionExpiresAt = '';
        _passwordController.clear();
      });
      _showMessage(_t('loggedOut'));
    });
  }

  Future<void> _changePassword() async {
    final current = TextEditingController();
    final next = TextEditingController();
    final values = await showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('changePassword')),
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
              decoration: InputDecoration(
                labelText: _t('newPassword'),
                helperText: _t('passwordHint'),
              ),
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
            child: Text(_t('changePassword')),
          ),
        ],
      ),
    );
    current.dispose();
    next.dispose();
    if (values == null || values.length != 2) return;
    if (values[1].length < 12) {
      _showMessage(_t('passwordRequired'));
      return;
    }
    await _run(() async {
      await _auth.changePassword(
        currentPassword: values[0],
        newPassword: values[1],
      );
      _showMessage(_t('passwordChanged'));
    });
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
                      final device = devices[index];
                      final current = device['current'] == true;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          current ? Icons.phone_iphone_rounded : Icons.devices,
                        ),
                        title: Text(
                          current ? _t('currentDevice') : _short(device['fingerprint']?.toString()),
                        ),
                        subtitle: Text(
                          '${_t('lastSeen')}: ${_formatDate(device['lastSeenAt']?.toString())}',
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

  Future<void> _deleteAccount() async {
    final password = TextEditingController();
    final confirmedPassword = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('deleteConfirmTitle')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_t('deleteConfirmBody')),
            const SizedBox(height: 14),
            TextField(
              controller: password,
              obscureText: true,
              decoration: InputDecoration(labelText: _t('password')),
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
              foregroundColor: SigillumTheme.ivory,
            ),
            onPressed: () => Navigator.pop(context, password.text),
            child: Text(_t('confirmDelete')),
          ),
        ],
      ),
    );
    password.dispose();
    if (confirmedPassword == null || confirmedPassword.isEmpty) return;
    await _run(() async {
      await _auth.deleteAccount(password: confirmedPassword);
      final identity = await HCVIdentity().loadIdentity();
      if (!mounted) return;
      setState(() {
        _identity = identity;
        _account = const {};
        _sessionExpiresAt = '';
        _emailController.clear();
        _passwordController.clear();
        _nameController.text = identity['creatorName']?.toString() ?? '';
      });
      _showMessage(_t('deleted'));
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _short(String? value, {int visible = 10}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '—';
    if (text.length <= visible * 2 + 1) return text;
    return '${text.substring(0, visible)}…${text.substring(text.length - visible)}';
  }

  String _formatDate(String? value) {
    final parsed = DateTime.tryParse(value ?? '');
    if (parsed == null) return '—';
    final local = parsed.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(_t('title'))),
        body: Center(child: Text(_t('loading'))),
      );
    }

    final localKycStatus = _identity['kycStatus']?.toString() ?? 'not_started';
    final onlineKycStatus = _account['kycStatus']?.toString();
    final kycStatus = onlineKycStatus?.isNotEmpty == true
        ? onlineKycStatus!
        : localKycStatus;
    final verified = kycStatus == 'verified';
    final creatorName = _nameController.text.trim();

    return Scaffold(
      appBar: AppBar(title: Text(_t('title'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 32),
        children: [
          _AccountSummary(
            name: creatorName,
            subtitle: _signedIn
                ? '${_account['email'] ?? ''} · ${_t('active')}'
                : verified
                    ? _t('verifiedIdentity')
                    : _t('localProfile'),
            verified: verified || _signedIn,
          ),
          if (_busy) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: SigillumTheme.danger)),
          ],
          const SizedBox(height: 18),
          _Section(
            title: _t('security'),
            children: _signedIn
                ? _signedInSecurityChildren()
                : _signedOutSecurityChildren(),
          ),
          const SizedBox(height: 14),
          _Section(
            title: _t('profile'),
            children: [
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: _t('declaredName'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _languageCode,
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
                onPressed: _busy ? null : _saveProfile,
                icon: const Icon(Icons.save_outlined),
                label: Text(_t('save')),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Section(
            title: _t('identity'),
            children: [
              _DetailRow(
                label: _t('creatorId'),
                value: _short(_identity['creatorId']?.toString()),
              ),
              _DetailRow(label: _t('kycStatus'), value: kycStatus),
              _DetailRow(
                label: _t('deviceKey'),
                value: _short(
                  _identity['devicePublicKeyFingerprint']?.toString(),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                IdentityPage(languageCode: _languageCode),
                          ),
                        );
                        await _loadAccount();
                      },
                icon: const Icon(Icons.badge_outlined),
                label: Text(_t('manageIdentity')),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Section(
            title: _t('privacy'),
            danger: true,
            children: [
              Text(
                _signedIn ? _t('deleteInfo') : _t('loginToDelete'),
                style: const TextStyle(
                  color: SigillumTheme.muted,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _signedIn && !_busy ? _deleteAccount : null,
                icon: const Icon(Icons.delete_forever_outlined),
                label: Text(_t('deleteAccount')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: SigillumTheme.danger,
                  side: BorderSide(
                    color: _signedIn
                        ? SigillumTheme.danger
                        : SigillumTheme.muted,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LegalInfoPage(languageCode: _languageCode),
                  ),
                ),
                icon: const Icon(Icons.privacy_tip_outlined),
                label: Text(_t('support')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _signedOutSecurityChildren() {
    return [
      _DetailRow(label: _t('session'), value: _t('notActive')),
      const SizedBox(height: 6),
      Text(
        _t('accessExplanation'),
        style: const TextStyle(
          color: SigillumTheme.muted,
          fontSize: 14,
          height: 1.35,
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        autocorrect: false,
        decoration: InputDecoration(
          labelText: _t('email'),
          border: const OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        autocorrect: false,
        enableSuggestions: false,
        decoration: InputDecoration(
          labelText: _t('password'),
          helperText: _t('passwordHint'),
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
            icon: Icon(
              _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: _busy ? null : _register,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: Text(_t('createAccount')),
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: _busy ? null : _login,
        icon: const Icon(Icons.login_rounded),
        label: Text(_t('login')),
      ),
    ];
  }

  List<Widget> _signedInSecurityChildren() {
    return [
      _DetailRow(label: _t('session'), value: _t('active')),
      _DetailRow(label: _t('email'), value: _account['email']?.toString() ?? '—'),
      _DetailRow(
        label: _t('deviceCount'),
        value: _account['deviceCount']?.toString() ?? '1',
      ),
      _DetailRow(
        label: _t('sessionExpires'),
        value: _formatDate(_sessionExpiresAt),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: _busy ? null : _showDevices,
        icon: const Icon(Icons.devices_rounded),
        label: Text(_t('devices')),
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: _busy ? null : _changePassword,
        icon: const Icon(Icons.password_rounded),
        label: Text(_t('changePassword')),
      ),
      const SizedBox(height: 10),
      FilledButton.icon(
        onPressed: _busy ? null : () => _logout(),
        icon: const Icon(Icons.logout_rounded),
        label: Text(_t('logout')),
      ),
      const SizedBox(height: 10),
      TextButton.icon(
        onPressed: _busy ? null : () => _logout(allDevices: true),
        icon: const Icon(Icons.phonelink_erase_rounded),
        label: Text(_t('logoutAll')),
      ),
    ];
  }
}

class _AccountSummary extends StatelessWidget {
  const _AccountSummary({
    required this.name,
    required this.subtitle,
    required this.verified,
  });

  final String name;
  final String subtitle;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: SigillumTheme.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: verified
              ? SigillumTheme.verified.withAlpha(110)
              : const Color(0x444B625A),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: verified
                ? SigillumTheme.verified.withAlpha(38)
                : SigillumTheme.accent.withAlpha(32),
            child: Icon(
              verified ? Icons.verified_user_rounded : Icons.person_rounded,
              color: verified ? SigillumTheme.verified : SigillumTheme.accent,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'SIGILLUM User' : name,
                  style: const TextStyle(
                    color: SigillumTheme.ivory,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: verified ? SigillumTheme.verified : SigillumTheme.muted,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.children,
    this.danger = false,
  });

  final String title;
  final List<Widget> children;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SigillumTheme.panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: danger
              ? SigillumTheme.danger.withAlpha(100)
              : const Color(0x334B625A),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: danger ? SigillumTheme.danger : SigillumTheme.ivory,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(
                color: SigillumTheme.muted,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 5,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: SigillumTheme.ivory,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
