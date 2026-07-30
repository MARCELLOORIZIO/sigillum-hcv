from pathlib import Path


def replace_once(source: str, old: str, new: str, label: str) -> str:
    if new in source:
        return source
    count = source.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one anchor, found {count}")
    return source.replace(old, new, 1)


page_path = Path('lib/account_page.dart')
page = page_path.read_text()

replacements = {
    "'save': 'SALVA MODIFICHE',": "'save': 'SALVA NOME E LINGUA',",
    "'createAccount': 'CREA ACCOUNT',": "'createAccount': 'CREA ACCOUNT ONLINE',",
    "'login': 'ACCEDI',": "'login': 'ACCEDI A UN ACCOUNT ESISTENTE',",
    "'save': 'SAVE CHANGES',": "'save': 'SAVE NAME AND LANGUAGE',",
    "'createAccount': 'CREATE ACCOUNT',": "'createAccount': 'CREATE ONLINE ACCOUNT',",
    "'login': 'LOG IN',": "'login': 'LOG IN TO AN EXISTING ACCOUNT',",
    "'save': 'GUARDAR CAMBIOS',": "'save': 'GUARDAR NOMBRE E IDIOMA',",
    "'createAccount': 'CREAR CUENTA',": "'createAccount': 'CREAR CUENTA EN LÍNEA',",
    "'login': 'ACCEDER',": "'login': 'ACCEDER A UNA CUENTA EXISTENTE',",
    "'save': 'СОХРАНИТЬ',": "'save': 'СОХРАНИТЬ ИМЯ И ЯЗЫК',",
    "'createAccount': 'СОЗДАТЬ АККАУНТ',": "'createAccount': 'СОЗДАТЬ ОНЛАЙН-АККАУНТ',",
    "'login': 'ВОЙТИ',": "'login': 'ВОЙТИ В СУЩЕСТВУЮЩИЙ АККАУНТ',",
}
for old, new in replacements.items():
    page = replace_once(page, old, new, old)

page = replace_once(
    page,
    """      'accessExplanation':
          'L’accesso collega il profilo online alla chiave sicura di questo dispositivo. Il token di sessione è custodito nel Keychain o nel Keystore.',
      'privacy': 'Privacy e dati',""",
    """      'accessExplanation':
          'L’accesso collega il profilo online alla chiave sicura di questo dispositivo. Il token di sessione è custodito nel Keychain o nel Keystore.',
      'accountActionHelp':
          'SALVA NOME E LINGUA aggiorna solo il profilo. Per registrarti inserisci nome, email e password, poi tocca CREA ACCOUNT ONLINE.',
      'privacy': 'Privacy e dati',""",
    'Italian Account help',
)
page = replace_once(
    page,
    """      'accessExplanation':
          'Access links the online profile to this device secure key. The session token is stored in Keychain or Keystore.',
      'privacy': 'Privacy and data',""",
    """      'accessExplanation':
          'Access links the online profile to this device secure key. The session token is stored in Keychain or Keystore.',
      'accountActionHelp':
          'SAVE NAME AND LANGUAGE only updates the profile. To register, enter name, email and password, then tap CREATE ONLINE ACCOUNT.',
      'privacy': 'Privacy and data',""",
    'English Account help',
)
page = replace_once(
    page,
    """      'accessExplanation':
          'El acceso vincula el perfil en línea con la clave segura del dispositivo. El token se guarda en Keychain o Keystore.',
      'privacy': 'Privacidad y datos',""",
    """      'accessExplanation':
          'El acceso vincula el perfil en línea con la clave segura del dispositivo. El token se guarda en Keychain o Keystore.',
      'accountActionHelp':
          'GUARDAR NOMBRE E IDIOMA solo actualiza el perfil. Para registrarte introduce nombre, correo y contraseña y toca CREAR CUENTA EN LÍNEA.',
      'privacy': 'Privacidad y datos',""",
    'Spanish Account help',
)
page = replace_once(
    page,
    """      'accessExplanation':
          'Вход связывает онлайн-профиль с защищенным ключом устройства. Токен хранится в Keychain или Keystore.',
      'privacy': 'Конфиденциальность и данные',""",
    """      'accessExplanation':
          'Вход связывает онлайн-профиль с защищенным ключом устройства. Токен хранится в Keychain или Keystore.',
      'accountActionHelp':
          'СОХРАНИТЬ ИМЯ И ЯЗЫК обновляет только профиль. Для регистрации введите имя, email и пароль и нажмите СОЗДАТЬ ОНЛАЙН-АККАУНТ.',
      'privacy': 'Конфиденциальность и данные',""",
    'Russian Account help',
)

page = replace_once(
    page,
    """      Text(
        _t('accessExplanation'),
        style: const TextStyle(
          color: SigillumTheme.muted,
          fontSize: 14,
          height: 1.35,
        ),
      ),
      const SizedBox(height: 12),
      TextField(""",
    """      Text(
        _t('accessExplanation'),
        style: const TextStyle(
          color: SigillumTheme.muted,
          fontSize: 14,
          height: 1.35,
        ),
      ),
      const SizedBox(height: 10),
      Text(
        _t('accountActionHelp'),
        style: const TextStyle(
          color: SigillumTheme.accent,
          fontSize: 14,
          height: 1.35,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 12),
      TextField(""",
    'signed-out Account instructions',
)
page_path.write_text(page)


service_path = Path('lib/hcv_auth_service.dart')
service = service_path.read_text()
service = replace_once(
    service,
    """      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HCVAuthException(
          decoded['message']?.toString() ??
              decoded['error']?.toString() ??
              'Operazione account non disponibile.',""",
    """      if (response.statusCode < 200 || response.statusCode >= 300) {
        final serverError = decoded['error']?.toString() ?? '';
        final serverMessage = decoded['message']?.toString() ?? '';
        final missingAccountEndpoint = response.statusCode == 404 &&
            (serverError == 'Endpoint non trovato' ||
                serverError == 'ENDPOINT_ACCOUNT_NON_TROVATO');
        throw HCVAuthException(
          missingAccountEndpoint
              ? 'Il server Account non è ancora aggiornato. Attendi il completamento del deploy Registry e riprova.'
              : serverMessage.isNotEmpty
                  ? serverMessage
                  : serverError.isNotEmpty
                      ? serverError
                      : 'Operazione account non disponibile.',""",
    'Account endpoint error mapping',
)
service_path.write_text(service)


test_path = Path('test/account_page_contract_test.dart')
test = test_path.read_text()
test = test.replace("contains(\"'createAccount': 'CREA ACCOUNT'\")", "contains(\"'createAccount': 'CREA ACCOUNT ONLINE'\")")
test = test.replace("contains(\"'login': 'ACCEDI'\")", "contains(\"'login': 'ACCEDI A UN ACCOUNT ESISTENTE'\")")
if "accountActionHelp" not in test:
    test = test.replace(
        "expect(source, contains('HCVAuthService'));",
        "expect(source, contains('HCVAuthService'));\n    expect(source, contains('accountActionHelp'));\n    expect(source, contains('SALVA NOME E LINGUA'));",
        1,
    )
test_path.write_text(test)

print('Account actions clarified without changing authentication semantics')
