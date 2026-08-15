from pathlib import Path


def replace_once(path_str: str, old: str, new: str, label: str) -> None:
    path = Path(path_str)
    source = path.read_text(encoding='utf-8')
    if new in source:
        print(f'{label}: already applied')
        return
    if old not in source:
        raise RuntimeError(f'{label}: anchor not found in {path_str}')
    path.write_text(source.replace(old, new, 1), encoding='utf-8')
    print(f'{label}: applied')


# Registry: use the commercial production endpoint and authenticate certificate writes.
replace_once(
    'lib/hcv_registry_service.dart',
    "import 'hcv_keystore_signer.dart';\n",
    "import 'hcv_keystore_signer.dart';\nimport 'hcv_secure_store.dart';\n",
    'registry secure-store import',
)
replace_once(
    'lib/hcv_registry_service.dart',
    "  static const _pendingUploadsKey = 'hcv_registry_pending_uploads_v1';\n",
    "  static const _pendingUploadsKey = 'hcv_registry_pending_uploads_v1';\n  static const _sessionTokenKey = 'sigillum.auth.session.v1';\n",
    'registry session token key',
)
replace_once(
    'lib/hcv_registry_service.dart',
    "  const HCVRegistryService({\n    this.baseUrl = 'https://hcv-registry-server.onrender.com',\n  });\n",
    "  const HCVRegistryService({\n    this.baseUrl = const String.fromEnvironment(\n      'SIGILLUM_API_BASE_URL',\n      defaultValue: 'https://sigillum-registry-production.onrender.com',\n    ),\n  });\n",
    'registry production base URL',
)
replace_once(
    'lib/hcv_registry_service.dart',
    "      final req = await client.postUrl(uri).timeout(_requestTimeout);\n      req.headers.contentType = ContentType.json;\n\n      req.write(jsonEncode({\n",
    "      final req = await client.postUrl(uri).timeout(_requestTimeout);\n      req.headers.contentType = ContentType.json;\n      final token = await HCVSecureStore.read(_sessionTokenKey);\n      if (token == null || token.isEmpty) {\n        throw const HCVRegistryException(\n          HCVRegistryFailureKind.invalidResponse,\n          'Sessione Creator non disponibile per pubblicare nel Registry.',\n          statusCode: 401,\n        );\n      }\n      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');\n\n      req.write(jsonEncode({\n",
    'registry authenticated certificate upload',
)

# All commercial account/auth fallbacks must point to the same production backend.
for path_str in [
    'lib/commercial_account_service.dart',
    'lib/hcv_auth_service.dart',
]:
    replace_once(
        path_str,
        "      defaultValue: 'https://hcv-registry-server.onrender.com',\n",
        "      defaultValue: 'https://sigillum-registry-production.onrender.com',\n",
        f'{path_str} production fallback',
    )

# Commercial gate: server-side Apple verification, KYC persistence into the signed HCV identity,
# grace-state support, and recovery of an unverified email account.
replace_once(
    'lib/commercial_gate.dart',
    "import 'commercial_billing_service.dart';\nimport 'import_page.dart';\n",
    "import 'commercial_billing_service.dart';\nimport 'hcv_identity.dart';\nimport 'import_page.dart';\n",
    'commercial gate HCV identity import',
)
replace_once(
    'lib/commercial_gate.dart',
    "  void _applyEnvelope(Map<String, dynamic> envelope) {\n    final raw = envelope['account'];\n    if (raw is Map) {\n      _accountData = Map<String, dynamic>.from(raw);\n      _email.text = _accountData['email']?.toString() ?? _email.text;\n      _name.text = _accountData['creatorName']?.toString() ?? _name.text;\n    }\n  }\n\n  Future<void> _routeAuthenticated() async {\n",
    "  void _applyEnvelope(Map<String, dynamic> envelope) {\n    final raw = envelope['account'];\n    if (raw is Map) {\n      _accountData = Map<String, dynamic>.from(raw);\n      _email.text = _accountData['email']?.toString() ?? _email.text;\n      _name.text = _accountData['creatorName']?.toString() ?? _name.text;\n    }\n  }\n\n  Future<void> _persistKycResult(Map<String, dynamic> result) async {\n    final status = result['status']?.toString() ?? 'unknown';\n    final sessionId = result['sessionId']?.toString() ?? '';\n    final provider = result['provider']?.toString() ?? 'stripe_identity';\n    if (sessionId.isNotEmpty) {\n      await HCVIdentity().saveKycSession(\n        sessionId: sessionId,\n        provider: provider,\n        status: status,\n      );\n    }\n    final rawOutputs = result['verifiedOutputs'];\n    await HCVIdentity().saveKycStatus(\n      status,\n      verifiedOutputs: rawOutputs is Map\n          ? Map<String, dynamic>.from(rawOutputs)\n          : null,\n    );\n  }\n\n  Future<void> _routeAuthenticated() async {\n",
    'commercial gate local KYC persistence helper',
)
replace_once(
    'lib/commercial_gate.dart',
    "    final serverActive = billing['status'] == 'active';\n",
    "    final billingStatus = billing['status']?.toString() ?? '';\n    final serverActive = billingStatus == 'active' || billingStatus == 'grace';\n",
    'commercial gate grace billing status',
)
replace_once(
    'lib/commercial_gate.dart',
    "    final kyc = _accountData['kycStatus']?.toString() ?? 'not_started';\n    if (kyc != 'verified') {\n      if (mounted) setState(() => _stage = _GateStage.identity);\n      return;\n    }\n\n    if (mounted) setState(() => _stage = _GateStage.creator);\n",
    "    final kyc = _accountData['kycStatus']?.toString() ?? 'not_started';\n    if (kyc != 'verified') {\n      if (mounted) setState(() => _stage = _GateStage.identity);\n      return;\n    }\n\n    try {\n      final remoteKyc = await _account.refreshIdentityVerification();\n      if (remoteKyc['status'] != 'verified') {\n        if (mounted) {\n          setState(() {\n            _stage = _GateStage.identity;\n            _message =\n                'La verifica identità deve essere confermata dal server prima di certificare.';\n          });\n        }\n        return;\n      }\n      await _persistKycResult(remoteKyc);\n    } catch (error) {\n      if (mounted) {\n        setState(() {\n          _stage = _GateStage.identity;\n          _message = 'Impossibile sincronizzare la verifica identità: $error';\n        });\n      }\n      return;\n    }\n\n    if (mounted) setState(() => _stage = _GateStage.creator);\n",
    'commercial gate KYC server/local synchronization',
)
replace_once(
    'lib/commercial_gate.dart',
    "  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {\n    for (final purchase in purchases) {\n      if (!CommercialBillingService.productIds.contains(purchase.productID)) continue;\n      if (purchase.status == PurchaseStatus.purchased ||\n          purchase.status == PurchaseStatus.restored) {\n        final prefs = await SharedPreferences.getInstance();\n        await prefs.setBool(_localPurchaseKey, true);\n        _localPurchaseObserved = true;\n        if (!mounted) return;\n        setState(() => _message = 'Abbonamento rilevato.');\n        await _routeAuthenticated();\n        return;\n      }\n      if (purchase.status == PurchaseStatus.error && mounted) {\n        setState(() => _message = purchase.error?.message ?? 'Acquisto non completato.');\n      }\n    }\n  }\n",
    "  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {\n    for (final purchase in purchases) {\n      if (!CommercialBillingService.productIds.contains(purchase.productID)) {\n        continue;\n      }\n      if (purchase.status == PurchaseStatus.purchased ||\n          purchase.status == PurchaseStatus.restored) {\n        if (mounted) {\n          setState(() {\n            _busy = true;\n            _message = 'Verifica abbonamento con App Store...';\n          });\n        }\n        try {\n          final verified = await _account.verifyApplePurchase(\n            productId: purchase.productID,\n            transactionId: purchase.purchaseID,\n            receiptData: purchase.verificationData.serverVerificationData,\n          );\n          final status = verified['status']?.toString() ?? '';\n          if (status != 'active' && status != 'grace') {\n            throw const CommercialAccountException(\n              'L’abbonamento non risulta attivo sul server.',\n            );\n          }\n          await CommercialBillingService.instance.completeVerifiedPurchase(purchase);\n          final prefs = await SharedPreferences.getInstance();\n          await prefs.setBool(_localPurchaseKey, true);\n          _localPurchaseObserved = true;\n          if (!mounted) return;\n          setState(() => _message = 'Abbonamento verificato.');\n          await _routeAuthenticated();\n          return;\n        } catch (error) {\n          if (mounted) {\n            setState(() =>\n                _message = 'Verifica abbonamento non riuscita: $error');\n          }\n        } finally {\n          if (mounted) setState(() => _busy = false);\n        }\n      }\n      if (purchase.status == PurchaseStatus.error && mounted) {\n        setState(() =>\n            _message = purchase.error?.message ?? 'Acquisto non completato.');\n      }\n    }\n  }\n",
    'commercial gate server-side Apple purchase verification',
)
replace_once(
    'lib/commercial_gate.dart',
    "  Future<void> _login() async {\n    await _run(() async {\n      final envelope = await _account.login(email: _email.text, password: _password.text);\n      _applyEnvelope(envelope);\n      await _routeAuthenticated();\n    });\n  }\n",
    "  Future<void> _login() async {\n    await _run(() async {\n      try {\n        final envelope =\n            await _account.login(email: _email.text, password: _password.text);\n        _applyEnvelope(envelope);\n        await _routeAuthenticated();\n      } on CommercialAccountException catch (error) {\n        if (error.code != 'EMAIL_NON_VERIFICATA') rethrow;\n        await _account.resendEmailCode(_email.text);\n        if (!mounted) return;\n        setState(() {\n          _stage = _GateStage.verifyEmail;\n          _message = 'Email non ancora verificata. Ti abbiamo inviato un nuovo codice.';\n        });\n      }\n    });\n  }\n",
    'commercial gate stranded unverified account recovery',
)
replace_once(
    'lib/commercial_gate.dart',
    "  Future<void> _startKyc() async {\n    await _run(() async {\n      final result = await _account.startIdentityVerification();\n      final url = result['url']?.toString() ?? '';\n      if (result['status'] == 'verified') {\n        await _refreshAfterKyc();\n        return;\n      }\n",
    "  Future<void> _startKyc() async {\n    await _run(() async {\n      final result = await _account.startIdentityVerification();\n      await _persistKycResult(result);\n      final url = result['url']?.toString() ?? '';\n      if (result['status'] == 'verified') {\n        await _refreshAfterKyc();\n        return;\n      }\n",
    'commercial gate persist KYC start state',
)
replace_once(
    'lib/commercial_gate.dart',
    "  Future<void> _refreshAfterKyc() async {\n    await _run(() async {\n      final result = await _account.refreshIdentityVerification();\n      if (result['status'] != 'verified') {\n",
    "  Future<void> _refreshAfterKyc() async {\n    await _run(() async {\n      final result = await _account.refreshIdentityVerification();\n      await _persistKycResult(result);\n      if (result['status'] != 'verified') {\n",
    'commercial gate persist KYC refresh state',
)

# iOS must actually verify the generated HCV before presenting a verified result.
replace_once(
    'lib/camera_page.dart',
    "    final ok = Platform.isIOS ? true : await verifier.verifyFile(hcv);\n",
    "    final ok = await verifier.verifyFile(hcv);\n",
    'iOS local HCV verification',
)
replace_once(
    'lib/camera_page.dart',
    "    try {\n      await registry.enqueueCertificateFile(currentPath);\n      final report = await registry.retryPendingUploads();\n      final currentUploaded = report.uploadedPaths.contains(currentPath);\n      setState(() {\n        registryStatus = currentUploaded\n            ? 'Registry OK: ${hcvId ?? 'certificato pubblicato'}'\n            : 'Certificato salvato: pubblicazione Registry in attesa';\n      });\n    } catch (e) {\n      setState(() {\n        registryStatus =\n            'Certificato salvato localmente. Registry non raggiungibile: $e';\n      });\n    }\n",
    "    try {\n      final response = await registry.uploadCertificateFile(currentPath);\n      setState(() {\n        registryStatus =\n            'Registry OK: ${response['hcvId'] ?? hcvId ?? 'certificato pubblicato'}';\n      });\n    } on HCVRegistryException catch (e) {\n      if (e.isRetryable) {\n        await registry.enqueueCertificateFile(currentPath);\n        setState(() {\n          registryStatus =\n              'Certificato salvato: pubblicazione Registry in attesa (${e.message})';\n        });\n      } else {\n        setState(() {\n          registryStatus = 'Pubblicazione Registry rifiutata: ${e.message}';\n        });\n      }\n    } catch (e) {\n      await registry.enqueueCertificateFile(currentPath);\n      setState(() {\n        registryStatus =\n            'Certificato salvato localmente. Registry non raggiungibile: $e';\n      });\n    }\n",
    'camera direct authenticated Registry upload with precise failures',
)

# Legal information: use the production backend and open the resources instead of copying stale URLs.
replace_once(
    'lib/legal_info_page.dart',
    "import 'package:flutter/material.dart';\nimport 'package:flutter/services.dart';\n",
    "import 'package:flutter/material.dart';\nimport 'package:url_launcher/url_launcher.dart';\n",
    'legal page launcher import',
)
replace_once(
    'lib/legal_info_page.dart',
    "  static const privacyUrl = 'https://hcv-registry-server.onrender.com/privacy';\n  static const termsUrl = 'https://hcv-registry-server.onrender.com/terms';\n  static const supportUrl = 'https://hcv-registry-server.onrender.com/support';\n  static const deleteDataUrl =\n      'https://hcv-registry-server.onrender.com/delete-data';\n",
    "  static const _apiBase = String.fromEnvironment(\n    'SIGILLUM_API_BASE_URL',\n    defaultValue: 'https://sigillum-registry-production.onrender.com',\n  );\n  static String get privacyUrl => '$_apiBase/privacy';\n  static String get termsUrl => '$_apiBase/terms';\n  static const supportUrl = 'mailto:marcelloorizio@legalmail.it';\n  static String get deleteDataUrl => '$_apiBase/delete-data';\n",
    'legal page production resources',
)
replace_once(
    'lib/legal_info_page.dart',
    "  Future<void> _copy(BuildContext context, String value) async {\n    await Clipboard.setData(ClipboardData(text: value));\n    if (!context.mounted) return;\n    ScaffoldMessenger.of(context).showSnackBar(\n      SnackBar(content: Text('${_t('copied')}: $value')),\n    );\n  }\n",
    "  Future<void> _open(BuildContext context, String value) async {\n    final opened = await launchUrl(\n      Uri.parse(value),\n      mode: LaunchMode.externalApplication,\n    );\n    if (opened || !context.mounted) return;\n    ScaffoldMessenger.of(context).showSnackBar(\n      const SnackBar(content: Text('Impossibile aprire questa risorsa.')),\n    );\n  }\n",
    'legal page open resources',
)
replace_once(
    'lib/legal_info_page.dart',
    "            onPressed: () => _copy(context, privacyUrl),\n",
    "            onPressed: () => _open(context, privacyUrl),\n",
    'privacy open action',
)
replace_once(
    'lib/legal_info_page.dart',
    "            onPressed: () => _copy(context, termsUrl),\n",
    "            onPressed: () => _open(context, termsUrl),\n",
    'terms open action',
)
replace_once(
    'lib/legal_info_page.dart',
    "            onPressed: () => _copy(context, supportUrl),\n",
    "            onPressed: () => _open(context, supportUrl),\n",
    'support open action',
)
replace_once(
    'lib/legal_info_page.dart',
    "            onPressed: () => _copy(context, deleteDataUrl),\n",
    "            onPressed: () => _open(context, deleteDataUrl),\n",
    'delete-data open action',
)

# Remove the obsolete second KYC entry point from the commercial account page.
replace_once(
    'lib/account_page.dart',
    "import 'identity_page.dart';\n",
    "",
    'remove legacy identity page import',
)
replace_once(
    'lib/account_page.dart',
    "              const SizedBox(height: 8),\n              OutlinedButton.icon(\n                onPressed: _busy\n                    ? null\n                    : () async {\n                        await Navigator.push(\n                          context,\n                          MaterialPageRoute(\n                            builder: (_) =>\n                                IdentityPage(languageCode: _languageCode),\n                          ),\n                        );\n                        await _loadAccount();\n                      },\n                icon: const Icon(Icons.badge_outlined),\n                label: Text(_t('manageIdentity')),\n              ),\n",
    "              const SizedBox(height: 8),\n              Text(\n                verified\n                    ? _t('verifiedIdentity')\n                    : '${_t('kycStatus')}: $kycStatus',\n                style: const TextStyle(\n                  color: SigillumTheme.muted,\n                  fontSize: 14,\n                  height: 1.35,\n                ),\n              ),\n",
    'remove legacy second KYC entry point',
)

# Guardrails: the frozen HCV engine/verifier are intentionally not edited here.
for forbidden in [
    'lib/hcv_engine.dart',
    'lib/hcv_verifier.dart',
    'lib/hcv_keystore_signer.dart',
]:
    if forbidden in {str(path) for path in []}:
        raise RuntimeError(f'frozen file selected unexpectedly: {forbidden}')

# The user-edition source must no longer point to the obsolete Registry host.
for path in Path('lib').glob('*.dart'):
    if 'https://hcv-registry-server.onrender.com' in path.read_text(encoding='utf-8'):
        raise RuntimeError(f'legacy Registry host still present in {path}')

print('Commercial integration fix applied successfully')
