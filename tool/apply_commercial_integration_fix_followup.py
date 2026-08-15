from pathlib import Path


def replace_required(path_str: str, old: str, new: str, label: str) -> None:
    path = Path(path_str)
    source = path.read_text(encoding='utf-8')
    if old not in source:
        raise RuntimeError(f'{label}: anchor not found in {path_str}')
    path.write_text(source.replace(old, new, 1), encoding='utf-8')
    print(f'{label}: applied')


def remove_required(path_str: str, old: str, label: str) -> None:
    replace_required(path_str, old, '', label)


# Registry contract: use one clearly named authenticated session token for writes.
replace_required(
    'lib/hcv_registry_service.dart',
    "      final token = await HCVSecureStore.read(_sessionTokenKey);\n      if (token == null || token.isEmpty) {\n",
    "      final sessionToken = await HCVSecureStore.read(_sessionTokenKey);\n      if (sessionToken == null || sessionToken.isEmpty) {\n",
    'registry session token naming',
)
replace_required(
    'lib/hcv_registry_service.dart',
    "      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');\n",
    "      req.headers.set(\n        HttpHeaders.authorizationHeader,\n        'Bearer $sessionToken',\n      );\n",
    'registry bearer session token',
)

# A StoreKit observation is never an entitlement. Remove all local/prelaunch purchase grants.
remove_required(
    'lib/commercial_gate.dart',
    "import 'package:shared_preferences/shared_preferences.dart';\n",
    'remove SharedPreferences billing import',
)
remove_required(
    'lib/commercial_gate.dart',
    "  static const bool _prelaunchBillingBypass = bool.fromEnvironment(\n    'SIGILLUM_PRELAUNCH_BILLING_BYPASS',\n    defaultValue: false,\n  );\n  static const _localPurchaseKey = 'sigillum_local_creator_purchase_observed_v1';\n\n",
    'remove prelaunch billing bypass constants',
)
remove_required(
    'lib/commercial_gate.dart',
    "  bool _billingEnforced = false;\n  bool _localPurchaseObserved = false;\n",
    'remove local billing state',
)
remove_required(
    'lib/commercial_gate.dart',
    "      final prefs = await SharedPreferences.getInstance();\n      _localPurchaseObserved = prefs.getBool(_localPurchaseKey) ?? false;\n",
    'remove local purchase bootstrap',
)
replace_required(
    'lib/commercial_gate.dart',
    "    _billingEnforced = billing['enforced'] == true;\n    final billingStatus = billing['status']?.toString() ?? '';\n    final serverActive = billingStatus == 'active' || billingStatus == 'grace';\n    final paid = serverActive ||\n        (!_billingEnforced && _localPurchaseObserved) ||\n        (!_billingEnforced && _prelaunchBillingBypass);\n\n    if (!paid) {\n",
    "    final serverStatus = billing['status']?.toString() ?? '';\n    final serverActive =\n        serverStatus == 'active' || serverStatus == 'grace';\n\n    if (!serverActive) {\n",
    'require server subscription entitlement',
)
remove_required(
    'lib/commercial_gate.dart',
    "          final prefs = await SharedPreferences.getInstance();\n          await prefs.setBool(_localPurchaseKey, true);\n          _localPurchaseObserved = true;\n",
    'remove local purchase grant after verification',
)
remove_required(
    'lib/commercial_gate.dart',
    "        if (_prelaunchBillingBypass && !_billingEnforced) ...[\n          const SizedBox(height: 8),\n          TextButton(onPressed: () async { _localPurchaseObserved = true; await _routeAuthenticated(); }, child: const Text('CONTINUA TEST PRE-LANCIO')),\n        ],\n",
    'remove UI billing bypass',
)

# When a commercial session is invalidated, return the gate to its landing state.
replace_required(
    'lib/commercial_gate.dart',
    "  Future<void> _logout() async {\n",
    "  void _onSessionInvalidated() {\n    if (!mounted) return;\n    setState(() {\n      _accountData = const {};\n      _password.clear();\n      _code.clear();\n      _stage = _GateStage.landing;\n    });\n  }\n\n  Future<void> _logout() async {\n",
    'commercial session invalidation handler',
)
replace_required(
    'lib/commercial_gate.dart',
    "    if (_stage == _GateStage.creator) return const UserHomePage();\n",
    "    if (_stage == _GateStage.creator) {\n      return UserHomePage(onSessionInvalidated: _onSessionInvalidated);\n    }\n",
    'commercial home session callback',
)

# Keep the legacy AccountPage intact for its legacy contract, but stop exposing it
# from the commercial user edition. The commercial profile is the single post-login account UI.
replace_required(
    'lib/account_page.dart',
    "import 'hcv_identity.dart';\n",
    "import 'hcv_identity.dart';\nimport 'identity_page.dart';\n",
    'restore legacy identity import',
)
replace_required(
    'lib/account_page.dart',
    "              const SizedBox(height: 8),\n              Text(\n                verified\n                    ? _t('verifiedIdentity')\n                    : '${_t('kycStatus')}: $kycStatus',\n                style: const TextStyle(\n                  color: SigillumTheme.muted,\n                  fontSize: 14,\n                  height: 1.35,\n                ),\n              ),\n",
    "              const SizedBox(height: 8),\n              OutlinedButton.icon(\n                onPressed: _busy\n                    ? null\n                    : () async {\n                        await Navigator.push(\n                          context,\n                          MaterialPageRoute(\n                            builder: (_) =>\n                                IdentityPage(languageCode: _languageCode),\n                          ),\n                        );\n                        await _loadAccount();\n                      },\n                icon: const Icon(Icons.badge_outlined),\n                label: Text(_t('manageIdentity')),\n              ),\n",
    'restore legacy AccountPage KYC control',
)

replace_required(
    'lib/user_home_page.dart',
    "import 'account_page.dart';\n",
    "import 'commercial_profile_page.dart';\n",
    'commercial profile import',
)
replace_required(
    'lib/user_home_page.dart',
    "class UserHomePage extends StatefulWidget {\n  const UserHomePage({super.key});\n",
    "class UserHomePage extends StatefulWidget {\n  const UserHomePage({super.key, this.onSessionInvalidated});\n\n  final VoidCallback? onSessionInvalidated;\n",
    'commercial home session callback field',
)
replace_required(
    'lib/user_home_page.dart',
    "                    AccountPage(\n                      languageCode: languageCode,\n                      onLanguageChanged: _setLanguage,\n                    ),\n",
    "                    CommercialProfilePage(\n                      languageCode: languageCode,\n                      onLanguageChanged: _setLanguage,\n                      onSessionInvalidated:\n                          widget.onSessionInvalidated ?? () {},\n                    ),\n",
    'header commercial account route',
)
replace_required(
    'lib/user_home_page.dart',
    "                      AccountPage(\n                        languageCode: languageCode,\n                        onLanguageChanged: _setLanguage,\n                      ),\n",
    "                      CommercialProfilePage(\n                        languageCode: languageCode,\n                        onLanguageChanged: _setLanguage,\n                        onSessionInvalidated:\n                            widget.onSessionInvalidated ?? () {},\n                      ),\n",
    'list commercial account route',
)

replace_required(
    'lib/commercial_profile_page.dart',
    "    final subscriptionActive = _billing['status'] == 'active' ||\n        _billing['status'] == 'development_allowed';\n",
    "    final subscriptionActive = _billing['status'] == 'active' ||\n        _billing['status'] == 'grace';\n",
    'commercial profile server subscription status',
)

# Final safety assertions for this follow-up.
gate = Path('lib/commercial_gate.dart').read_text(encoding='utf-8')
for forbidden in [
    'SharedPreferences.getInstance()',
    '_localPurchaseObserved',
    '_localPurchaseKey',
    'SIGILLUM_PRELAUNCH_BILLING_BYPASS',
]:
    if forbidden in gate:
        raise RuntimeError(f'local billing grant still present: {forbidden}')

home = Path('lib/user_home_page.dart').read_text(encoding='utf-8')
if 'AccountPage(' in home or 'CommercialProfilePage(' not in home:
    raise RuntimeError('commercial home account route not unified')

for frozen in [
    'lib/hcv_engine.dart',
    'lib/hcv_verifier.dart',
    'lib/hcv_keystore_signer.dart',
]:
    if not Path(frozen).exists():
        raise RuntimeError(f'frozen HCV core missing: {frozen}')

print('Commercial entitlement and profile follow-up applied successfully')
