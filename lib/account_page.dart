import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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

  Map<String, dynamic> _identity = const {};
  late String _languageCode;
  bool _loading = true;
  bool _saving = false;
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
      'technicalIdentity': 'Identità tecnica locale',
      'verifiedIdentity': 'Identità legale verificata',
      'creatorId': 'ID tecnico creator',
      'kycStatus': 'Stato KYC',
      'deviceKey': 'Chiave dispositivo',
      'manageIdentity': 'GESTISCI IDENTITÀ E KYC',
      'security': 'Sicurezza e accesso',
      'session': 'Sessione online',
      'notActive': 'Non attiva',
      'logout': 'LOGOUT',
      'logoutUnavailable':
          'SIGILLUM usa attualmente un’identità tecnica locale, non una sessione online. Il logout sarà attivato insieme al sistema di login.',
      'privacy': 'Privacy e dati',
      'deleteAccount': 'RICHIEDI ELIMINAZIONE ACCOUNT E DATI',
      'deleteInfo':
          'La richiesta viene avviata dalla pagina ufficiale di cancellazione. Sono indicati i dati eliminabili e gli eventuali dati tecnici da conservare per obblighi legali o integrità dei certificati.',
      'deleteConfirmTitle': 'Richiesta di eliminazione',
      'deleteConfirmBody':
          'Vuoi aprire la pagina ufficiale per richiedere l’eliminazione dell’account e dei dati associati?',
      'cancel': 'ANNULLA',
      'continue': 'CONTINUA',
      'openFailed': 'Impossibile aprire la pagina di eliminazione.',
      'support': 'SUPPORTO E PRIVACY',
      'loading': 'Caricamento account...',
      'loadFailed': 'Impossibile caricare i dati account.',
      'nameRequired': 'Inserisci un nome dichiarato.',
      'localProfile': 'Profilo locale collegato a questo dispositivo',
    },
    'en': {
      'title': 'Account',
      'profile': 'Profile',
      'declaredName': 'Declared name',
      'save': 'SAVE CHANGES',
      'saved': 'Profile updated',
      'language': 'Language',
      'identity': 'Identity and verification',
      'technicalIdentity': 'Local technical identity',
      'verifiedIdentity': 'Verified legal identity',
      'creatorId': 'Technical creator ID',
      'kycStatus': 'KYC status',
      'deviceKey': 'Device key',
      'manageIdentity': 'MANAGE IDENTITY AND KYC',
      'security': 'Security and access',
      'session': 'Online session',
      'notActive': 'Not active',
      'logout': 'LOG OUT',
      'logoutUnavailable':
          'SIGILLUM currently uses a local technical identity, not an online session. Log out will be enabled with the login system.',
      'privacy': 'Privacy and data',
      'deleteAccount': 'REQUEST ACCOUNT AND DATA DELETION',
      'deleteInfo':
          'The request starts from the official deletion page. It explains which data can be deleted and which technical records may need to be retained for legal or certificate-integrity reasons.',
      'deleteConfirmTitle': 'Deletion request',
      'deleteConfirmBody':
          'Open the official page to request deletion of the account and associated data?',
      'cancel': 'CANCEL',
      'continue': 'CONTINUE',
      'openFailed': 'Unable to open the deletion page.',
      'support': 'SUPPORT AND PRIVACY',
      'loading': 'Loading account...',
      'loadFailed': 'Unable to load account data.',
      'nameRequired': 'Enter a declared name.',
      'localProfile': 'Local profile linked to this device',
    },
    'es': {
      'title': 'Cuenta',
      'profile': 'Perfil',
      'declaredName': 'Nombre declarado',
      'save': 'GUARDAR CAMBIOS',
      'saved': 'Perfil actualizado',
      'language': 'Idioma',
      'identity': 'Identidad y verificación',
      'technicalIdentity': 'Identidad técnica local',
      'verifiedIdentity': 'Identidad legal verificada',
      'creatorId': 'ID técnico del creador',
      'kycStatus': 'Estado KYC',
      'deviceKey': 'Clave del dispositivo',
      'manageIdentity': 'GESTIONAR IDENTIDAD Y KYC',
      'security': 'Seguridad y acceso',
      'session': 'Sesión en línea',
      'notActive': 'No activa',
      'logout': 'CERRAR SESIÓN',
      'logoutUnavailable':
          'SIGILLUM utiliza actualmente una identidad técnica local, no una sesión en línea. El cierre de sesión se activará con el sistema de acceso.',
      'privacy': 'Privacidad y datos',
      'deleteAccount': 'SOLICITAR ELIMINACIÓN DE CUENTA Y DATOS',
      'deleteInfo':
          'La solicitud comienza en la página oficial de eliminación, donde se indican los datos eliminables y los registros técnicos que deban conservarse.',
      'deleteConfirmTitle': 'Solicitud de eliminación',
      'deleteConfirmBody':
          '¿Abrir la página oficial para solicitar la eliminación de la cuenta y los datos asociados?',
      'cancel': 'CANCELAR',
      'continue': 'CONTINUAR',
      'openFailed': 'No se puede abrir la página de eliminación.',
      'support': 'SOPORTE Y PRIVACIDAD',
      'loading': 'Cargando cuenta...',
      'loadFailed': 'No se pueden cargar los datos de la cuenta.',
      'nameRequired': 'Introduce un nombre declarado.',
      'localProfile': 'Perfil local vinculado a este dispositivo',
    },
    'ru': {
      'title': 'Аккаунт',
      'profile': 'Профиль',
      'declaredName': 'Указанное имя',
      'save': 'СОХРАНИТЬ',
      'saved': 'Профиль обновлен',
      'language': 'Язык',
      'identity': 'Личность и проверка',
      'technicalIdentity': 'Локальная техническая личность',
      'verifiedIdentity': 'Подтвержденная юридическая личность',
      'creatorId': 'Технический ID автора',
      'kycStatus': 'Статус KYC',
      'deviceKey': 'Ключ устройства',
      'manageIdentity': 'УПРАВЛЕНИЕ ЛИЧНОСТЬЮ И KYC',
      'security': 'Безопасность и доступ',
      'session': 'Онлайн-сессия',
      'notActive': 'Не активна',
      'logout': 'ВЫЙТИ',
      'logoutUnavailable':
          'Сейчас SIGILLUM использует локальную техническую личность, а не онлайн-сессию. Выход появится вместе с системой входа.',
      'privacy': 'Конфиденциальность и данные',
      'deleteAccount': 'ЗАПРОСИТЬ УДАЛЕНИЕ АККАУНТА И ДАННЫХ',
      'deleteInfo':
          'Запрос начинается на официальной странице удаления, где указано, какие данные удаляются и какие технические записи могут храниться.',
      'deleteConfirmTitle': 'Запрос на удаление',
      'deleteConfirmBody':
          'Открыть официальную страницу для удаления аккаунта и связанных данных?',
      'cancel': 'ОТМЕНА',
      'continue': 'ПРОДОЛЖИТЬ',
      'openFailed': 'Не удалось открыть страницу удаления.',
      'support': 'ПОДДЕРЖКА И КОНФИДЕНЦИАЛЬНОСТЬ',
      'loading': 'Загрузка аккаунта...',
      'loadFailed': 'Не удалось загрузить данные аккаунта.',
      'nameRequired': 'Введите имя.',
      'localProfile': 'Локальный профиль этого устройства',
    },
  };

  String _t(String key) =>
      (_copy[_languageCode] ?? _copy['en']!)[key] ?? _copy['en']![key] ?? key;

  @override
  void initState() {
    super.initState();
    _languageCode = widget.languageCode;
    _loadAccount();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadAccount() async {
    try {
      final identity = await HCVIdentity().loadIdentity();
      if (!mounted) return;
      setState(() {
        _identity = identity;
        _nameController.text = identity['creatorName']?.toString() ?? '';
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _t('loadFailed');
      });
    }
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showMessage(_t('nameRequired'));
      return;
    }

    setState(() => _saving = true);
    try {
      await HCVIdentity().saveCreatorName(name);
      await _loadAccount();
      if (!mounted) return;
      _showMessage(_t('saved'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changeLanguage(String? code) async {
    if (code == null || code == _languageCode) return;
    await widget.onLanguageChanged(code);
    if (!mounted) return;
    setState(() => _languageCode = code);
  }

  Future<void> _openDeletionRequest() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('deleteConfirmTitle')),
        content: Text(_t('deleteConfirmBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_t('continue')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final opened = await launchUrl(
      Uri.parse(LegalInfoPage.deleteDataUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) _showMessage(_t('openFailed'));
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _short(String? value, {int visible = 12}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '—';
    if (text.length <= visible * 2 + 1) return text;
    return '${text.substring(0, visible)}…${text.substring(text.length - visible)}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(_t('title'))),
        body: Center(child: Text(_t('loading'))),
      );
    }

    final kycStatus = _identity['kycStatus']?.toString() ?? 'not_started';
    final verified = kycStatus == 'verified';
    final creatorName = _identity['creatorName']?.toString() ?? '';

    return Scaffold(
      appBar: AppBar(title: Text(_t('title'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 32),
        children: [
          _AccountSummary(
            name: creatorName,
            subtitle: verified ? _t('verifiedIdentity') : _t('localProfile'),
            verified: verified,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: SigillumTheme.danger)),
          ],
          const SizedBox(height: 18),
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
                onChanged: _changeLanguage,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _saving ? null : _saveProfile,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
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
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => IdentityPage(languageCode: _languageCode),
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
            title: _t('security'),
            children: [
              _DetailRow(label: _t('session'), value: _t('notActive')),
              const SizedBox(height: 6),
              Text(
                _t('logoutUnavailable'),
                style: const TextStyle(
                  color: SigillumTheme.muted,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.logout_rounded),
                label: Text(_t('logout')),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Section(
            title: _t('privacy'),
            danger: true,
            children: [
              Text(
                _t('deleteInfo'),
                style: const TextStyle(
                  color: SigillumTheme.muted,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _openDeletionRequest,
                icon: const Icon(Icons.delete_forever_outlined),
                label: Text(_t('deleteAccount')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: SigillumTheme.danger,
                  side: const BorderSide(color: SigillumTheme.danger),
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
