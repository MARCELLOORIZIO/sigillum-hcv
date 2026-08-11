import 'dart:async';

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'commercial_account_service.dart';
import 'commercial_billing_service.dart';
import 'import_page.dart';
import 'legal_info_page.dart';
import 'sigillum_theme.dart';
import 'user_home_page.dart';

class CommercialGate extends StatefulWidget {
  const CommercialGate({super.key});

  @override
  State<CommercialGate> createState() => _CommercialGateState();
}

enum _GateStage {
  loading,
  landing,
  auth,
  verifyEmail,
  billing,
  identity,
  creator,
}

class _CommercialGateState extends State<CommercialGate> {
  static const bool _prelaunchBillingBypass = bool.fromEnvironment(
    'SIGILLUM_PRELAUNCH_BILLING_BYPASS',
    defaultValue: false,
  );
  static const _localPurchaseKey = 'sigillum_local_creator_purchase_observed_v1';

  final CommercialAccountService _account = const CommercialAccountService();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  final _newPassword = TextEditingController();

  _GateStage _stage = _GateStage.loading;
  Map<String, dynamic> _accountData = const {};
  bool _busy = false;
  bool _loginMode = false;
  bool _forgotMode = false;
  bool _acceptTerms = false;
  bool _ackPrivacy = false;
  bool _adult = false;
  bool _obscure = true;
  bool _storeAvailable = false;
  bool _billingEnforced = false;
  bool _localPurchaseObserved = false;
  List<ProductDetails> _products = const [];
  String _message = '';
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  @override
  void initState() {
    super.initState();
    CommercialBillingService.instance.startListening();
    _purchaseSub = CommercialBillingService.instance.purchases.listen(_onPurchases);
    _bootstrap();
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _code.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _localPurchaseObserved = prefs.getBool(_localPurchaseKey) ?? false;
      final envelope = await _account.restoreAccount();
      if (!mounted) return;
      if (envelope == null) {
        setState(() => _stage = _GateStage.landing);
        return;
      }
      _applyEnvelope(envelope);
      await _routeAuthenticated();
    } catch (_) {
      if (mounted) setState(() => _stage = _GateStage.landing);
    }
  }

  void _applyEnvelope(Map<String, dynamic> envelope) {
    final raw = envelope['account'];
    if (raw is Map) {
      _accountData = Map<String, dynamic>.from(raw);
      _email.text = _accountData['email']?.toString() ?? _email.text;
      _name.text = _accountData['creatorName']?.toString() ?? _name.text;
    }
  }

  Future<void> _routeAuthenticated() async {
    final verifiedEmail = _accountData['emailVerified'] == true;
    if (!verifiedEmail) {
      setState(() => _stage = _GateStage.verifyEmail);
      return;
    }

    Map<String, dynamic> billing = const {};
    try {
      billing = await _account.billingStatus();
    } catch (_) {}
    _billingEnforced = billing['enforced'] == true;
    final serverActive = billing['status'] == 'active';
    final paid = serverActive ||
        (!_billingEnforced && _localPurchaseObserved) ||
        (!_billingEnforced && _prelaunchBillingBypass);

    if (!paid) {
      await _prepareBilling();
      if (mounted) setState(() => _stage = _GateStage.billing);
      return;
    }

    final kyc = _accountData['kycStatus']?.toString() ?? 'not_started';
    if (kyc != 'verified') {
      if (mounted) setState(() => _stage = _GateStage.identity);
      return;
    }

    if (mounted) setState(() => _stage = _GateStage.creator);
  }

  Future<void> _prepareBilling() async {
    try {
      _storeAvailable = await CommercialBillingService.instance.isAvailable();
      _products = _storeAvailable
          ? await CommercialBillingService.instance.loadProducts()
          : const [];
    } catch (error) {
      _message = 'App Store non disponibile: $error';
      _products = const [];
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (!CommercialBillingService.productIds.contains(purchase.productID)) continue;
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_localPurchaseKey, true);
        _localPurchaseObserved = true;
        if (!mounted) return;
        setState(() => _message = 'Abbonamento rilevato.');
        await _routeAuthenticated();
        return;
      }
      if (purchase.status == PurchaseStatus.error && mounted) {
        setState(() => _message = purchase.error?.message ?? 'Acquisto non completato.');
      }
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

  Future<void> _register() async {
    if (_name.text.trim().isEmpty ||
        !_email.text.contains('@') ||
        _password.text.length < 12) {
      setState(() => _message = 'Inserisci nome, email valida e una password di almeno 12 caratteri.');
      return;
    }
    if (!_acceptTerms || !_ackPrivacy || !_adult) {
      setState(() => _message = 'Per creare un account Creator devi completare le tre conferme richieste.');
      return;
    }
    await _run(() async {
      await _account.register(
        email: _email.text,
        password: _password.text,
        creatorName: _name.text,
        acceptTerms: _acceptTerms,
        acknowledgePrivacy: _ackPrivacy,
        adultConfirmed: _adult,
      );
      if (!mounted) return;
      setState(() {
        _stage = _GateStage.verifyEmail;
        _message = 'Ti abbiamo inviato un codice di 6 cifre.';
      });
    });
  }

  Future<void> _verifyEmail() async {
    if (_code.text.trim().length != 6) {
      setState(() => _message = 'Inserisci il codice di 6 cifre.');
      return;
    }
    await _run(() async {
      await _account.verifyEmail(email: _email.text, code: _code.text);
      final envelope = await _account.login(email: _email.text, password: _password.text);
      _applyEnvelope(envelope);
      await _routeAuthenticated();
    });
  }

  Future<void> _login() async {
    await _run(() async {
      final envelope = await _account.login(email: _email.text, password: _password.text);
      _applyEnvelope(envelope);
      await _routeAuthenticated();
    });
  }

  Future<void> _forgot() async {
    await _run(() async {
      if (_code.text.trim().isEmpty) {
        await _account.forgotPassword(_email.text);
        if (!mounted) return;
        setState(() => _message = 'Codice di recupero inviato. Inseriscilo qui sotto.');
      } else {
        if (_newPassword.text.length < 12) {
          throw const CommercialAccountException('La nuova password deve contenere almeno 12 caratteri.');
        }
        await _account.resetPassword(
          email: _email.text,
          code: _code.text,
          newPassword: _newPassword.text,
        );
        if (!mounted) return;
        setState(() {
          _forgotMode = false;
          _password.text = _newPassword.text;
          _code.clear();
          _newPassword.clear();
          _message = 'Password aggiornata. Ora puoi accedere.';
        });
      }
    });
  }

  Future<void> _startKyc() async {
    await _run(() async {
      final result = await _account.startIdentityVerification();
      final url = result['url']?.toString() ?? '';
      if (result['status'] == 'verified') {
        await _refreshAfterKyc();
        return;
      }
      if (url.isEmpty) throw StateError('Link di verifica identità non disponibile.');
      final opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!opened) throw StateError('Impossibile aprire la verifica identità.');
      if (mounted) setState(() => _message = 'Completa la verifica e poi torna in SIGILLUM.');
    });
  }

  Future<void> _refreshAfterKyc() async {
    await _run(() async {
      final result = await _account.refreshIdentityVerification();
      if (result['status'] != 'verified') {
        if (mounted) setState(() => _message = 'Verifica ancora in corso: ${result['status'] ?? 'unknown'}');
        return;
      }
      final envelope = await _account.restoreAccount();
      if (envelope != null) _applyEnvelope(envelope);
      if (mounted) setState(() => _stage = _GateStage.creator);
    });
  }

  Future<void> _logout() async {
    await _account.logout();
    if (!mounted) return;
    setState(() {
      _accountData = const {};
      _password.clear();
      _code.clear();
      _stage = _GateStage.landing;
    });
  }

  void _openVerify() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ImportPage(languageCode: 'it')),
    );
  }

  void _openLegal() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LegalInfoPage(languageCode: 'it')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_stage == _GateStage.creator) return const UserHomePage();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 36),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _content(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content() {
    switch (_stage) {
      case _GateStage.loading:
        return const Center(child: CircularProgressIndicator());
      case _GateStage.landing:
        return _landing();
      case _GateStage.auth:
        return _auth();
      case _GateStage.verifyEmail:
        return _verifyEmailView();
      case _GateStage.billing:
        return _billing();
      case _GateStage.identity:
        return _identity();
      case _GateStage.creator:
        return const SizedBox.shrink();
    }
  }

  Widget _brand({String? subtitle}) {
    return Column(
      children: [
        Container(
          width: 66,
          height: 66,
          decoration: BoxDecoration(
            color: SigillumTheme.ivory,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.security_rounded, color: SigillumTheme.ink, size: 38),
        ),
        const SizedBox(height: 16),
        const Text('SIGILLUM', style: TextStyle(fontSize: 31, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text(
          subtitle ?? 'Human Content Verification',
          textAlign: TextAlign.center,
          style: const TextStyle(color: SigillumTheme.muted, fontSize: 16, height: 1.3),
        ),
      ],
    );
  }

  Widget _landing() {
    return Column(
      key: const ValueKey('landing'),
      children: [
        _brand(subtitle: 'Verifica gratuitamente contenuti certificati oppure diventa un Creator verificato.'),
        const SizedBox(height: 34),
        FilledButton.icon(
          onPressed: _openVerify,
          icon: const Icon(Icons.verified_outlined),
          label: const Text('VERIFICA CONTENUTO — GRATIS'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => setState(() => _stage = _GateStage.auth),
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text('DIVENTA CREATOR'),
        ),
        const SizedBox(height: 18),
        TextButton(onPressed: _openLegal, child: const Text('Privacy, Termini e informazioni')),
      ],
    );
  }

  Widget _auth() {
    return Column(
      key: const ValueKey('auth'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _brand(subtitle: _forgotMode ? 'Recupera il tuo account' : (_loginMode ? 'Accedi al tuo account Creator' : 'Crea il tuo account Creator')),
        const SizedBox(height: 24),
        if (!_loginMode && !_forgotMode) ...[
          TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Nome', border: OutlineInputBorder())),
          const SizedBox(height: 12),
        ],
        TextField(controller: _email, keyboardType: TextInputType.emailAddress, autocorrect: false, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        if (!_forgotMode)
          TextField(
            controller: _password,
            obscureText: _obscure,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: 'Password',
              helperText: 'Almeno 12 caratteri',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(onPressed: () => setState(() => _obscure = !_obscure), icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined)),
            ),
          ),
        if (_forgotMode) ...[
          TextField(controller: _code, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Codice ricevuto (lascia vuoto per inviarlo)', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _newPassword, obscureText: true, decoration: const InputDecoration(labelText: 'Nuova password', border: OutlineInputBorder())),
        ],
        if (!_loginMode && !_forgotMode) ...[
          const SizedBox(height: 14),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _acceptTerms,
            onChanged: _busy ? null : (v) => setState(() => _acceptTerms = v == true),
            title: const Text('Accetto i Termini di Servizio'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _ackPrivacy,
            onChanged: _busy ? null : (v) => setState(() => _ackPrivacy = v == true),
            title: const Text('Ho preso visione dell’Informativa Privacy'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _adult,
            onChanged: _busy ? null : (v) => setState(() => _adult = v == true),
            title: const Text('Confermo di avere almeno 18 anni'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          TextButton(onPressed: _openLegal, child: const Text('LEGGI PRIVACY E TERMINI')),
        ],
        const SizedBox(height: 10),
        if (_busy) const LinearProgressIndicator(),
        if (_message.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(_message, textAlign: TextAlign.center, style: const TextStyle(color: SigillumTheme.accent)),
        ],
        const SizedBox(height: 14),
        FilledButton(
          onPressed: _busy ? null : (_forgotMode ? _forgot : (_loginMode ? _login : _register)),
          child: Text(_forgotMode ? (_code.text.trim().isEmpty ? 'INVIA CODICE' : 'REIMPOSTA PASSWORD') : (_loginMode ? 'ACCEDI' : 'CREA ACCOUNT')),
        ),
        if (!_forgotMode) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: _busy ? null : () => setState(() => _loginMode = !_loginMode),
            child: Text(_loginMode ? 'Non hai un account? CREA ACCOUNT' : 'Hai già un account? ACCEDI'),
          ),
          if (_loginMode)
            TextButton(onPressed: _busy ? null : () => setState(() => _forgotMode = true), child: const Text('PASSWORD DIMENTICATA?')),
        ] else
          TextButton(onPressed: _busy ? null : () => setState(() => _forgotMode = false), child: const Text('TORNA ALL’ACCESSO')),
        TextButton(onPressed: () => setState(() => _stage = _GateStage.landing), child: const Text('INDIETRO')),
      ],
    );
  }

  Widget _verifyEmailView() {
    return Column(
      key: const ValueKey('verify-email'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _brand(subtitle: 'Verifica il tuo indirizzo email'),
        const SizedBox(height: 22),
        Text('Abbiamo inviato un codice a ${_email.text}.', textAlign: TextAlign.center),
        const SizedBox(height: 18),
        TextField(controller: _code, keyboardType: TextInputType.number, maxLength: 6, textAlign: TextAlign.center, style: const TextStyle(fontSize: 28, letterSpacing: 8), decoration: const InputDecoration(labelText: 'Codice di 6 cifre', border: OutlineInputBorder())),
        if (_busy) const LinearProgressIndicator(),
        if (_message.isNotEmpty) Text(_message, textAlign: TextAlign.center, style: const TextStyle(color: SigillumTheme.accent)),
        const SizedBox(height: 12),
        FilledButton(onPressed: _busy ? null : _verifyEmail, child: const Text('CONFERMA EMAIL')),
        TextButton(onPressed: _busy ? null : () => _run(() => _account.resendEmailCode(_email.text)), child: const Text('INVIA NUOVO CODICE')),
      ],
    );
  }

  Widget _billing() {
    return Column(
      key: const ValueKey('billing'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _brand(subtitle: 'Attiva SIGILLUM Creator'),
        const SizedBox(height: 20),
        const _Feature(text: 'Certificazione foto, video e testo'),
        const _Feature(text: 'Identità verificata'),
        const _Feature(text: 'Registry HCV e verifica pubblica'),
        const _Feature(text: 'HCVPACK e coordinate opzionali'),
        const SizedBox(height: 18),
        if (_products.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(border: Border.all(color: SigillumTheme.muted), borderRadius: BorderRadius.circular(10)),
            child: Text(
              _storeAvailable
                  ? 'I prodotti App Store non sono ancora configurati per questo account di test.'
                  : 'App Store non disponibile su questo dispositivo.',
              textAlign: TextAlign.center,
            ),
          )
        else
          for (final product in _products) ...[
            FilledButton(
              onPressed: _busy ? null : () => _run(() async { await CommercialBillingService.instance.purchase(product); }),
              child: Text('${product.id == CommercialBillingService.annualProductId ? 'ANNUALE' : 'MENSILE'} — ${product.price}'),
            ),
            const SizedBox(height: 10),
          ],
        OutlinedButton(onPressed: _busy ? null : () => CommercialBillingService.instance.restore(), child: const Text('RIPRISTINA ACQUISTI')),
        if (_prelaunchBillingBypass && !_billingEnforced) ...[
          const SizedBox(height: 8),
          TextButton(onPressed: () async { _localPurchaseObserved = true; await _routeAuthenticated(); }, child: const Text('CONTINUA TEST PRE-LANCIO')),
        ],
        if (_message.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_message, textAlign: TextAlign.center, style: const TextStyle(color: SigillumTheme.accent))),
        const SizedBox(height: 12),
        TextButton(onPressed: _logout, child: const Text('ESCI DALL’ACCOUNT')),
      ],
    );
  }

  Widget _identity() {
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
        FilledButton.icon(onPressed: _busy ? null : _startKyc, icon: const Icon(Icons.badge_outlined), label: const Text('VERIFICA IDENTITÀ')),
        const SizedBox(height: 10),
        OutlinedButton(onPressed: _busy ? null : _refreshAfterKyc, child: const Text('HO COMPLETATO — CONTROLLA STATO')),
        if (_busy) const Padding(padding: EdgeInsets.only(top: 10), child: LinearProgressIndicator()),
        if (_message.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_message, textAlign: TextAlign.center, style: const TextStyle(color: SigillumTheme.accent))),
        const SizedBox(height: 12),
        TextButton(onPressed: _openLegal, child: const Text('PRIVACY E INFORMAZIONI SULLA VERIFICA')),
        TextButton(onPressed: _logout, child: const Text('ESCI DALL’ACCOUNT')),
      ],
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: SigillumTheme.verified),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
