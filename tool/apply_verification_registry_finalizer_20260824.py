from pathlib import Path

copy_path = Path('lib/verification_ui_copy.dart')
copy = copy_path.read_text(encoding='utf-8')

copy_insertions = {
    "      'registryNotFound': 'Certificato non presente nel Registry.',\n": """      'registryNotFound': 'Certificato non presente nel Registry.',
      'registryNotFoundDetail': 'Il certificato non è ancora presente nel Registry. Questo non dimostra che il file sia stato modificato: la pubblicazione online potrebbe essere ancora in attesa.',
      'registryUnavailableDetail': 'Il Registry non è raggiungibile in questo momento. La verifica online non può essere completata ora.',
      'registryOriginalHint': 'Il certificato viene recuperato automaticamente dal Registry HCV. Devi selezionare SOLO il file originale.',
      'notOnline': 'Non presente online',
      'registryUnavailableState': 'Registry non raggiungibile',
      'registryPendingProvenanceDetail': 'Il certificato non è ancora disponibile online per questo HCV-ID.',
      'registryUnavailableProvenanceDetail': 'Il Registry non è raggiungibile, quindi la provenienza online non può essere confermata.',
      'registryUnknownIntegrityDetail': 'Senza il certificato online non è possibile determinare se il file selezionato corrisponde al contenuto certificato.',
      'registryUnknownSceneDetail': 'Senza il certificato online la scena non può essere valutata rispetto alle evidenze firmate.',
      'invalidCertificate': 'Certificato non valido',
      'invalidCertificateDetail': 'Il certificato, la firma o il collegamento tecnico non risultano validi.',
      'mediaNotVerified': 'File non corrispondente',
      'mediaNotVerifiedDetail': 'Il certificato esiste, ma il file selezionato non corrisponde al contenuto certificato.',
""",
    "      'registryNotFound': 'Certificate not found in the Registry.',\n": """      'registryNotFound': 'Certificate not found in the Registry.',
      'registryNotFoundDetail': 'The certificate is not yet present in the Registry. This does not prove that the file was modified: online publication may still be pending.',
      'registryUnavailableDetail': 'The Registry cannot be reached right now. Online verification cannot be completed at this time.',
      'registryOriginalHint': 'The certificate is retrieved automatically from the HCV Registry. Select ONLY the original file.',
      'notOnline': 'Not available online',
      'registryUnavailableState': 'Registry unavailable',
      'registryPendingProvenanceDetail': 'The certificate is not yet available online for this HCV-ID.',
      'registryUnavailableProvenanceDetail': 'The Registry is unreachable, so online provenance cannot be confirmed.',
      'registryUnknownIntegrityDetail': 'Without the online certificate it is not possible to determine whether the selected file matches the certified content.',
      'registryUnknownSceneDetail': 'Without the online certificate the scene cannot be evaluated against the signed evidence.',
      'invalidCertificate': 'Invalid certificate',
      'invalidCertificateDetail': 'The certificate, signature, or technical linkage is not valid.',
      'mediaNotVerified': 'File does not match',
      'mediaNotVerifiedDetail': 'The certificate exists, but the selected file does not match the certified content.',
""",
    "      'registryNotFound': 'Certificado no encontrado en Registry.',\n": """      'registryNotFound': 'Certificado no encontrado en Registry.',
      'registryNotFoundDetail': 'El certificado aún no está presente en Registry. Esto no demuestra que el archivo haya sido modificado: la publicación en línea puede seguir pendiente.',
      'registryUnavailableDetail': 'Registry no está disponible en este momento. La verificación en línea no puede completarse ahora.',
      'registryOriginalHint': 'El certificado se recupera automáticamente de HCV Registry. Selecciona SOLO el archivo original.',
      'notOnline': 'No disponible en línea',
      'registryUnavailableState': 'Registry no disponible',
      'registryPendingProvenanceDetail': 'El certificado aún no está disponible en línea para este HCV-ID.',
      'registryUnavailableProvenanceDetail': 'Registry no está disponible, por lo que no se puede confirmar la procedencia en línea.',
      'registryUnknownIntegrityDetail': 'Sin el certificado en línea no se puede determinar si el archivo seleccionado coincide con el contenido certificado.',
      'registryUnknownSceneDetail': 'Sin el certificado en línea no se puede evaluar la escena frente a las evidencias firmadas.',
      'invalidCertificate': 'Certificado no válido',
      'invalidCertificateDetail': 'El certificado, la firma o la vinculación técnica no son válidos.',
      'mediaNotVerified': 'El archivo no coincide',
      'mediaNotVerifiedDetail': 'El certificado existe, pero el archivo seleccionado no coincide con el contenido certificado.',
""",
    "      'registryNotFound': 'Сертификат не найден в Registry.',\n": """      'registryNotFound': 'Сертификат не найден в Registry.',
      'registryNotFoundDetail': 'Сертификат пока отсутствует в Registry. Это не означает, что файл был изменён: публикация в сети может всё ещё ожидать выполнения.',
      'registryUnavailableDetail': 'Registry сейчас недоступен. Онлайн-проверку невозможно завершить в данный момент.',
      'registryOriginalHint': 'Сертификат автоматически загружается из HCV Registry. Выберите ТОЛЬКО оригинальный файл.',
      'notOnline': 'Нет в сети',
      'registryUnavailableState': 'Registry недоступен',
      'registryPendingProvenanceDetail': 'Сертификат для этого HCV-ID пока недоступен в сети.',
      'registryUnavailableProvenanceDetail': 'Registry недоступен, поэтому подтвердить происхождение онлайн сейчас невозможно.',
      'registryUnknownIntegrityDetail': 'Без онлайн-сертификата невозможно определить, соответствует ли выбранный файл сертифицированному контенту.',
      'registryUnknownSceneDetail': 'Без онлайн-сертификата сцену невозможно сопоставить с подписанными техническими данными.',
      'invalidCertificate': 'Недействительный сертификат',
      'invalidCertificateDetail': 'Сертификат, подпись или техническая связь недействительны.',
      'mediaNotVerified': 'Файл не соответствует',
      'mediaNotVerifiedDetail': 'Сертификат существует, но выбранный файл не соответствует сертифицированному контенту.',
""",
}
for old, new in copy_insertions.items():
    if new not in copy:
        if old not in copy:
            raise RuntimeError(f'verification copy anchor missing: {old.strip()}')
        copy = copy.replace(old, new, 1)
copy_path.write_text(copy, encoding='utf-8')

path = Path('lib/registry_verify_page.dart')
source = path.read_text(encoding='utf-8')

source = source.replace(
    "final claims = cert is Map ? cert['claims'] : null;",
    "final claims = cert?['claims'];",
    1,
)

old_public_title = """  String get _publicResultTitle {
    if (_isForensicResult) return _v('forensicOk');
    if (_isSocialResult) return _v('socialOk');
    if ((result ?? '').contains('REGISTRY NOT FOUND')) return _v('registryNotFound');
    if ((result ?? '').contains('REGISTRY UNAVAILABLE')) return _v('registryUnavailable');
    return _v('verificationIncomplete');
  }

  String get _publicResultDetail {
    if (_isForensicResult) return _v('forensicOkDetail');
    if (_isSocialResult) return _v('socialOkDetail');
    return status;
  }
"""
new_public_title = """  String get _publicResultTitle {
    if (_isForensicResult) return _v('forensicOk');
    if (_isSocialResult) return _v('socialOk');
    if (_isMediaNotVerified) return _v('mediaNotVerified');
    if (_isInvalidResult) return _v('invalidCertificate');
    if ((result ?? '').contains('REGISTRY NOT FOUND')) return _v('registryNotFound');
    if ((result ?? '').startsWith('REGISTRY ')) return _v('registryUnavailable');
    return _v('verificationIncomplete');
  }

  String get _publicResultDetail {
    if (_isForensicResult) return _v('forensicOkDetail');
    if (_isSocialResult) return _v('socialOkDetail');
    if (_isMediaNotVerified) return _v('mediaNotVerifiedDetail');
    if (_isInvalidResult) return _v('invalidCertificateDetail');
    if ((result ?? '').contains('REGISTRY NOT FOUND')) return _v('registryNotFoundDetail');
    if ((result ?? '').startsWith('REGISTRY ')) return _v('registryUnavailableDetail');
    return _v('verificationIncomplete');
  }
"""
if old_public_title in source:
    source = source.replace(old_public_title, new_public_title, 1)
elif "_v('registryNotFoundDetail')" not in source:
    raise RuntimeError('Registry public result helper anchor missing')

old_state_head = """  String _localizedAxisState(String axis, String? raw) {
    final value = (raw ?? '').toLowerCase();
"""
new_state_head = """  String _localizedAxisState(String axis, String? raw) {
    final value = (raw ?? '').toLowerCase();
    if (_isRegistryWarningResult) {
      if (axis == 'provenance') {
        return (result ?? '').contains('REGISTRY NOT FOUND')
            ? _v('notOnline')
            : _v('registryUnavailableState');
      }
      if (axis == 'integrity') return _v('notDetermined');
      if (axis == 'scene') return _v('notAnalyzed');
    }
"""
if old_state_head in source:
    source = source.replace(old_state_head, new_state_head, 1)
elif "return (result ?? '').contains('REGISTRY NOT FOUND')" not in source:
    raise RuntimeError('Registry axis state helper anchor missing')

old_detail_head = """  String _localizedAxisDetail(String axis) {
    if (axis == 'scene' && _signedRealityScene) return _v('realityDetail');
"""
new_detail_head = """  String _localizedAxisDetail(String axis) {
    if (_isRegistryWarningResult) {
      final notFound = (result ?? '').contains('REGISTRY NOT FOUND');
      if (axis == 'provenance') {
        return notFound
            ? _v('registryPendingProvenanceDetail')
            : _v('registryUnavailableProvenanceDetail');
      }
      if (axis == 'integrity') return _v('registryUnknownIntegrityDetail');
      if (axis == 'scene') return _v('registryUnknownSceneDetail');
    }
    if (axis == 'scene' && _signedRealityScene) return _v('realityDetail');
"""
if old_detail_head in source:
    source = source.replace(old_detail_head, new_detail_head, 1)
elif "_v('registryPendingProvenanceDetail')" not in source:
    raise RuntimeError('Registry axis detail helper anchor missing')

old_axis_color = """  Color _axisColor(String? value) {
    final normalized = value?.toLowerCase() ?? '';
    if (normalized.contains('non verificata') ||
        normalized.contains('non originale') ||
        normalized.contains('modificat') ||
        normalized.contains('mismatch')) {
      return Colors.red;
    }
    if (normalized.contains('cautela') ||
        normalized.contains('compatibile') ||
        normalized.contains('conclusiva') ||
        normalized.contains('non presente') ||
        normalized.contains('non raggiungibile') ||
        normalized.contains('non determinata') ||
        normalized.contains('non analizzata') ||
        normalized.contains('incompleta') ||
        normalized.contains('valido') ||
        normalized.contains('derivato')) {
      return Colors.orange;
    }
    if (normalized.contains('verificata') ||
        normalized.contains('integro') ||
        normalized.contains('nessun')) {
      return Colors.green;
    }
    return Colors.grey;
  }
"""
new_axis_color = """  Color _axisColor(String? value) {
    final normalized = value?.toLowerCase() ?? '';
    if (normalized.contains('forte rischio') ||
        normalized.contains('possibile schermo') ||
        normalized.contains('non verificata') ||
        normalized.contains('non originale') ||
        normalized.contains('mismatch')) {
      return Colors.red;
    }
    if (normalized.contains('cautela') ||
        normalized.contains('compatibile') ||
        normalized.contains('conclusiva') ||
        normalized.contains('non presente') ||
        normalized.contains('non raggiungibile') ||
        normalized.contains('non determinata') ||
        normalized.contains('non analizzata') ||
        normalized.contains('incompleta') ||
        normalized.contains('valido') ||
        normalized.contains('derivato')) {
      return Colors.orange;
    }
    if (normalized.contains('verificata') ||
        normalized.contains('integro') ||
        normalized.contains('nessun') ||
        normalized.contains('realtà') ||
        normalized.contains('realta') ||
        normalized.contains('non necessaria')) {
      return Colors.green;
    }
    return Colors.grey;
  }

  Color get _overallSeverityColor {
    if (result == null) return Colors.grey;
    if (_isStrongDisplayRisk || _isInvalidResult || _isMediaNotVerified) {
      return Colors.red;
    }
    if (_isDisplayNonConclusive || _isRegistryWarningResult) {
      return Colors.orange;
    }
    if (isVerified) return Colors.green;
    return Colors.orange;
  }

  IconData get _overallSeverityIcon {
    if (result == null) return Icons.cloud_sync;
    if (_overallSeverityColor == Colors.green) return Icons.verified;
    if (_overallSeverityColor == Colors.orange) return Icons.warning_amber;
    return Icons.error;
  }
"""
if old_axis_color in source:
    source = source.replace(old_axis_color, new_axis_color, 1)
elif 'Color get _overallSeverityColor' not in source:
    raise RuntimeError('Registry semantic color anchor missing')

old_icon = """              Icon(
                result == null
                    ? Icons.cloud_sync
                    : isVerified
                        ? Icons.verified
                        : isScreenReplayWarning || _isRegistryWarningResult
                            ? Icons.warning_amber
                            : Icons.error,
                size: 72,
                color: result == null
                    ? Colors.grey
                    : isVerified
                        ? Colors.green
                        : isScreenReplayWarning || _isRegistryWarningResult
                            ? Colors.orange
                            : Colors.red,
              ),
"""
new_icon = """              Icon(
                _overallSeverityIcon,
                size: 72,
                color: _overallSeverityColor,
              ),
"""
if old_icon in source:
    source = source.replace(old_icon, new_icon, 1)
elif '_overallSeverityIcon,' not in source:
    raise RuntimeError('Registry result icon anchor missing')

old_result_color = """                    color: isVerified
                        ? Colors.green
                        : isScreenReplayWarning || _isRegistryWarningResult
                            ? Colors.orange
                            : Colors.red,
"""
if old_result_color in source:
    source = source.replace(old_result_color, "                    color: _overallSeverityColor,\n", 1)

old_hint = """              const Text(
                'Il certificato viene recuperato automaticamente dal Registry HCV. Devi selezionare SOLO il file originale.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
"""
new_hint = """              Text(
                _v('registryOriginalHint'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
"""
if old_hint in source:
    source = source.replace(old_hint, new_hint, 1)
elif "_v('registryOriginalHint')" not in source:
    raise RuntimeError('Registry original-media hint anchor missing')

starts = [
    "              if (hcvTrustLevel != null || liveCaptureTrust != null || screenReplayRisk != null) ...[\n",
    "              if (hcvTrustLevel != null ||\n",
]
start = -1
for marker in starts:
    pos = source.find(marker)
    if pos >= 0:
        start = pos
        break

if start >= 0:
    end_marker = "            ],\n          ),\n"
    end = source.find(end_marker, start)
    if end < 0:
        raise RuntimeError('Registry technical block end anchor missing')
    compact = """              if (hcvTrustLevel != null ||
                  liveCaptureTrust != null ||
                  screenReplayRisk != null) ...[
                const SizedBox(height: 14),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.90),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: SigillumTheme.border),
                  ),
                  child: ExpansionTile(
                    title: Text(
                      _v('technicalDetails'),
                      style: const TextStyle(
                        color: SigillumTheme.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                    children: [
                      Text(
                        'HCV: ${hcvTrustLevel ?? '-'}\\n'
                        '${_v('scene')}: ${_localizedAxisState('scene', _effectiveSceneState)}\\n'
                        'Display: ${displayRiskDecision ?? '-'} / ${screenReplayRisk ?? '-'} / ${screenReplayRiskScore ?? '-'}\\n'
                        'Live probe: ${liveProbeAnalysisStatus ?? '-'} / ${liveProbeRisk ?? '-'}\\n'
                        'AI: ${aiProofLevel ?? '-'}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: SigillumTheme.muted,
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
"""
    source = source[:start] + compact + source[end:]

source = source.replace(
    "color: const Color(0xFF111A17),\n        borderRadius: BorderRadius.circular(8),",
    "color: Colors.white.withValues(alpha: 0.96),\n        borderRadius: BorderRadius.circular(26),",
)
source = source.replace(
    "color: SigillumTheme.panel,\n        borderRadius: BorderRadius.circular(28),",
    "color: Colors.white.withValues(alpha: 0.96),\n        borderRadius: BorderRadius.circular(26),",
)

for token in [
    "_v('technicalDetails')",
    "_v('provenanceHint')",
    "_v('integrityHint')",
    "_v('sceneHint')",
    "_v('derivationHint')",
    "_v('registryNotFoundDetail')",
    "_v('registryOriginalHint')",
    "_v('notOnline')",
    'Color get _overallSeverityColor',
    "normalized.contains('forte rischio')",
    '_signedRealityScene',
    "final claims = cert?['claims'];",
]:
    if token not in source:
        raise RuntimeError(f'Registry final UI token missing: {token}')

path.write_text(source, encoding='utf-8')
print('Registry verification finalized with full localization, semantic severity colors and compact diagnostics')
