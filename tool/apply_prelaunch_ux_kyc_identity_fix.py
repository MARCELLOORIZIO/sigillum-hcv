from pathlib import Path
import re


def replace_once(source, old, new, label):
    if old in source:
        return source.replace(old, new, 1)
    if new in source:
        return source
    raise RuntimeError(f'{label} anchor missing')


gate_path = Path('lib/commercial_gate.dart')
gate = gate_path.read_text(encoding='utf-8')

material_import = "import 'package:flutter/material.dart';\n"
services_import = "import 'package:flutter/services.dart';\n"
if services_import not in gate:
    if material_import not in gate:
        raise RuntimeError('Flutter material import anchor missing')
    gate = gate.replace(material_import, material_import + services_import, 1)

persist_pattern = re.compile(
    r"  Future<void> _persistKycResult\(Map<String, dynamic> result\) async \{.*?\n  \}\n\n  Future<void> _routeAuthenticated",
    re.S,
)
persist_replacement = r'''  Future<void> _persistKycResult(Map<String, dynamic> result) async {
    final status = result['status']?.toString() ?? 'unknown';
    final sessionId = result['sessionId']?.toString() ?? '';
    final provider = result['provider']?.toString() ?? 'stripe_identity';
    final verificationLivemode = result['verificationLivemode'] == true;
    if (sessionId.isNotEmpty) {
      await HCVIdentity().saveKycSession(
        sessionId: sessionId,
        provider: provider,
        status: status,
      );
    }
    final rawOutputs = verificationLivemode ? result['verifiedOutputs'] : null;
    await HCVIdentity().saveKycStatus(
      status,
      verifiedOutputs:
          rawOutputs is Map ? Map<String, dynamic>.from(rawOutputs) : null,
    );
    if (mounted) {
      setState(() {
        _accountData = <String, dynamic>{
          ..._accountData,
          'kycStatus': status,
        };
      });
    }
  }

  Future<void> _routeAuthenticated'''
gate, persist_count = persist_pattern.subn(persist_replacement, gate, count=1)
if persist_count != 1 and 'final verificationLivemode = result' not in gate:
    raise RuntimeError('KYC persistence anchor missing')

route_anchor = "  Future<void> _routeAuthenticated() async {\n"
route_sync = """  Future<void> _routeAuthenticated() async {
    final accountCreatorName =
        _accountData['creatorName']?.toString().trim() ?? '';
    if (accountCreatorName.isNotEmpty) {
      await HCVIdentity().saveCreatorName(accountCreatorName);
    }
"""
if 'final accountCreatorName =' not in gate:
    gate = replace_once(gate, route_anchor, route_sync, 'local creator-name sync')

start_pattern = re.compile(
    r"  Future<void> _startKyc\(\) async \{.*?\n  \}\n\n  Future<void> _refreshAfterKyc",
    re.S,
)
start_replacement = r'''  Future<void> _startKyc() async {
    await _run(() async {
      final result = await _account.startIdentityVerification();
      await _persistKycResult(result);
      final status = result['status']?.toString() ?? 'unknown';
      final url = result['url']?.toString() ?? '';
      if (status == 'verified') {
        await _refreshAfterKyc();
        return;
      }
      if (status == 'processing') {
        if (mounted) {
          setState(() => _message =
              'Verifica inviata a Stripe. Il controllo è in elaborazione.');
        }
        return;
      }
      if (url.isEmpty) {
        throw StateError(
            'Link di verifica identità non disponibile per lo stato $status.');
      }
      final opened =
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!opened) throw StateError('Impossibile aprire la verifica identità.');
      if (mounted) {
        setState(() => _message = status == 'requires_input'
            ? 'Stripe richiede un ulteriore passaggio. Completa la verifica e poi torna in SIGILLUM.'
            : 'Completa la verifica e poi torna in SIGILLUM.');
      }
    });
  }

  Future<void> _refreshAfterKyc'''
gate, start_count = start_pattern.subn(start_replacement, gate, count=1)
if start_count != 1 and 'Verifica inviata a Stripe. Il controllo è in elaborazione.' not in gate:
    raise RuntimeError('KYC start anchor missing')

refresh_pattern = re.compile(
    r"  Future<void> _refreshAfterKyc\(\) async \{.*?\n  \}\n\n  void _onSessionInvalidated",
    re.S,
)
refresh_replacement = r'''  Future<void> _refreshAfterKyc() async {
    await _run(() async {
      final result = await _account.refreshIdentityVerification();
      await _persistKycResult(result);
      final status = result['status']?.toString() ?? 'unknown';
      if (status != 'verified') {
        if (mounted) {
          final text = switch (status) {
            'processing' =>
              'Verifica inviata a Stripe. Il controllo è in elaborazione.',
            'requires_input' =>
              'Stripe richiede un ulteriore passaggio per completare la verifica.',
            'canceled' =>
              'La verifica è stata annullata. Puoi avviare una nuova verifica.',
            _ => 'Stato verifica identità: $status',
          };
          setState(() => _message = text);
        }
        return;
      }
      final envelope = await _account.restoreAccount();
      if (envelope != null) {
        _applyEnvelope(envelope);
        final accountCreatorName =
            _accountData['creatorName']?.toString().trim() ?? '';
        if (result['verificationLivemode'] != true &&
            accountCreatorName.isNotEmpty) {
          await HCVIdentity().saveCreatorName(accountCreatorName);
        }
      }
      if (mounted) setState(() => _stage = _GateStage.creator);
    });
  }

  void _onSessionInvalidated'''
gate, refresh_count = refresh_pattern.subn(refresh_replacement, gate, count=1)
if refresh_count != 1 and "Stripe richiede un ulteriore passaggio per completare la verifica." not in gate:
    raise RuntimeError('KYC refresh anchor missing')

landing_pattern = re.compile(
    r"  Widget _landing\(\) \{.*?\n  \}\n\n  Widget _auth\(\)",
    re.S,
)
landing_replacement = r'''  Widget _landing() {
    return Column(
      key: const ValueKey('landing'),
      children: [
        _brand(
            subtitle:
                'Verifica gratuitamente contenuti certificati, accedi al tuo account oppure diventa un Creator verificato.'),
        const SizedBox(height: 34),
        FilledButton.icon(
          onPressed: _openVerify,
          icon: const Icon(Icons.verified_outlined),
          label: const Text('VERIFICA CONTENUTO — GRATIS'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => setState(() {
            _loginMode = true;
            _forgotMode = false;
            _stage = _GateStage.auth;
          }),
          icon: const Icon(Icons.login_rounded),
          label: const Text('ACCEDI AL TUO ACCOUNT'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => setState(() {
            _loginMode = false;
            _forgotMode = false;
            _stage = _GateStage.auth;
          }),
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text('DIVENTA CREATOR'),
        ),
        const SizedBox(height: 18),
        TextButton(
            onPressed: _openLegal,
            child: const Text('Privacy, Termini e informazioni')),
      ],
    );
  }

  Widget _auth()'''
gate, landing_count = landing_pattern.subn(landing_replacement, gate, count=1)
if landing_count != 1 and 'ACCEDI AL TUO ACCOUNT' not in gate:
    raise RuntimeError('landing UX anchor missing')

email_anchor = """        TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
"""
email_replacement = """        TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.username, AutofillHints.email],
            autocorrect: false,
"""
if 'AutofillHints.username, AutofillHints.email' not in gate:
    gate = replace_once(gate, email_anchor, email_replacement, 'email autofill')

password_anchor = """          TextField(
            controller: _password,
            obscureText: _obscure,
            autocorrect: false,
"""
password_replacement = """          TextField(
            controller: _password,
            obscureText: _obscure,
            autofillHints: _loginMode
                ? const [AutofillHints.password]
                : const [AutofillHints.newPassword],
            autocorrect: false,
"""
if 'const [AutofillHints.newPassword]' not in gate:
    gate = replace_once(gate, password_anchor, password_replacement, 'password autofill')

code_pattern = re.compile(
    r"(controller: _code,\n)(\s+)(keyboardType: TextInputType\.number,)(?!\n\2autofillHints:)"
)
gate = code_pattern.sub(
    lambda m: m.group(1) + m.group(2) + m.group(3) + '\n' + m.group(2) +
    'autofillHints: const [AutofillHints.oneTimeCode],',
    gate,
)

new_password_anchor = """          TextField(
              controller: _newPassword,
              obscureText: true,
              decoration: const InputDecoration(
"""
new_password_replacement = """          TextField(
              controller: _newPassword,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              decoration: const InputDecoration(
"""
if 'controller: _newPassword' in gate and 'controller: _newPassword,\n              obscureText: true,\n              autofillHints:' not in gate:
    gate = replace_once(
        gate,
        new_password_anchor,
        new_password_replacement,
        'reset-password autofill',
    )

verify_login_anchor = """      final envelope =
          await _account.login(email: _email.text, password: _password.text);
      _applyEnvelope(envelope);
      await _routeAuthenticated();
"""
verify_login_replacement = """      final envelope =
          await _account.login(email: _email.text, password: _password.text);
      _applyEnvelope(envelope);
      TextInput.finishAutofillContext(shouldSave: true);
      await _routeAuthenticated();
"""
if verify_login_anchor in gate:
    gate = gate.replace(verify_login_anchor, verify_login_replacement, 1)

login_anchor = """        final envelope =
            await _account.login(email: _email.text, password: _password.text);
        _applyEnvelope(envelope);
        await _routeAuthenticated();
"""
login_replacement = """        final envelope =
            await _account.login(email: _email.text, password: _password.text);
        _applyEnvelope(envelope);
        TextInput.finishAutofillContext(shouldSave: true);
        await _routeAuthenticated();
"""
if login_anchor in gate:
    gate = gate.replace(login_anchor, login_replacement, 1)

identity_pattern = re.compile(
    r"  Widget _identity\(\) \{.*?\n  \}\n\}\n\nclass _Feature",
    re.S,
)
identity_replacement = r'''  Widget _identity() {
    final status = _accountData['kycStatus']?.toString() ?? 'not_started';
    final processing = status == 'processing';
    final requiresInput = status == 'requires_input';
    final canceled = status == 'canceled';
    final verified = status == 'verified';
    final actionLabel = verified
        ? 'IDENTITÀ VERIFICATA'
        : processing
            ? 'VERIFICA IN ELABORAZIONE'
            : requiresInput
                ? 'CONTINUA VERIFICA IDENTITÀ'
                : canceled
                    ? 'RIPROVA VERIFICA IDENTITÀ'
                    : 'VERIFICA IDENTITÀ';

    return Column(
      key: const ValueKey('identity'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _brand(subtitle: 'Ultimo passaggio: verifica la tua identità'),
        const SizedBox(height: 22),
        const Text(
          'Per associare i certificati a un Creator reale, SIGILLUM utilizza Stripe Identity. La procedura richiede un documento valido e un controllo selfie. I documenti vengono gestiti tramite Stripe; SIGILLUM conserva lo stato della verifica e i dati tecnici minimi necessari.',
          textAlign: TextAlign.center,
          style: TextStyle(color: SigillumTheme.muted, height: 1.4),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
            onPressed: _busy || processing || verified ? null : _startKyc,
            icon: const Icon(Icons.badge_outlined),
            label: Text(actionLabel)),
        if (processing) ...[
          const SizedBox(height: 10),
          const Text(
            'La verifica è stata inviata a Stripe. Attendi l’esito prima di avviare altre procedure.',
            textAlign: TextAlign.center,
            style: TextStyle(color: SigillumTheme.muted),
          ),
        ],
        const SizedBox(height: 10),
        OutlinedButton(
            onPressed: _busy ? null : _refreshAfterKyc,
            child: const Text('AGGIORNA STATO VERIFICA')),
        if (_busy)
          const Padding(
              padding: EdgeInsets.only(top: 10),
              child: LinearProgressIndicator()),
        if (_message.isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: SigillumTheme.accent))),
        const SizedBox(height: 12),
        TextButton(
            onPressed: _openLegal,
            child: const Text('PRIVACY E INFORMAZIONI SULLA VERIFICA')),
        TextButton(onPressed: _logout, child: const Text('ESCI DALL’ACCOUNT')),
      ],
    );
  }
}

class _Feature'''
gate, identity_count = identity_pattern.subn(identity_replacement, gate, count=1)
if identity_count != 1 and 'CONTINUA VERIFICA IDENTITÀ' not in gate:
    raise RuntimeError('KYC identity UI anchor missing')

for token in [
    'ACCEDI AL TUO ACCOUNT',
    'AutofillHints.username',
    'AutofillHints.password',
    'AutofillHints.newPassword',
    'AutofillHints.oneTimeCode',
    'TextInput.finishAutofillContext(shouldSave: true)',
    'CONTINUA VERIFICA IDENTITÀ',
    'VERIFICA IN ELABORAZIONE',
    "result['verificationLivemode'] == true",
]:
    if token not in gate:
        raise RuntimeError(f'commercial UX/KYC token missing: {token}')

gate_path.write_text(gate, encoding='utf-8')

identity_path = Path('lib/hcv_identity.dart')
identity = identity_path.read_text(encoding='utf-8')
verified_output_anchor = """    final country = verifiedOutputs?[\"country\"]?.toString().trim() ?? \"\";

    if (legalName.isNotEmpty) {
"""
verified_output_replacement = """    final country = verifiedOutputs?[\"country\"]?.toString().trim() ?? \"\";

    if (status == \"verified\" && verifiedOutputs == null) {
      await prefs.remove(_kycLegalNameKey);
      await prefs.remove(_kycCountryKey);
    }

    if (legalName.isNotEmpty) {
"""
if 'status == "verified" && verifiedOutputs == null' not in identity:
    identity = replace_once(
        identity,
        verified_output_anchor,
        verified_output_replacement,
        'test KYC verified-output cleanup',
    )
identity_path.write_text(identity, encoding='utf-8')

auth_path = Path('lib/hcv_auth_service.dart')
auth = auth_path.read_text(encoding='utf-8')
delete_anchor = """    await HCVSecureStore.delete(_sessionTokenKey);
  }

  Future<String> _requiredToken() async {
"""
delete_replacement = """    await HCVSecureStore.delete(_sessionTokenKey);
    await HCVIdentity().clearPersonalData();
  }

  Future<String> _requiredToken() async {
"""
if 'await HCVIdentity().clearPersonalData();' not in auth:
    auth = replace_once(
        auth,
        delete_anchor,
        delete_replacement,
        'account-deletion local identity cleanup',
    )
auth_path.write_text(auth, encoding='utf-8')

print('Commercial landing, AutoFill, KYC state UX and account identity cleanup applied')
