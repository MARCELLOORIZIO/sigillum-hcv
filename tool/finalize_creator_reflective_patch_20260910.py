from pathlib import Path


def replace_once(path: str, old: str, new: str, marker: str) -> bool:
    file = Path(path)
    source = file.read_text(encoding='utf-8')
    if old in source:
        file.write_text(source.replace(old, new, 1), encoding='utf-8')
        print(f'patched {path}: {marker}')
        return True
    if marker in source:
        print(f'already patched {path}: {marker}')
        return False
    raise RuntimeError(f'cannot find expected source block in {path}: {marker}')


# ---------------------------------------------------------------------------
# 1) Reflective flat-surface guard.
# Preserve the frozen/legacy ML-only contract when the richer diagnostics are
# absent, but when current runtime diagnostics are present require independent
# regional/frame corroboration before ML alone can produce STRONG_DISPLAY_RISK.
# ---------------------------------------------------------------------------
photo_old = """    // A framed print, glossy photograph or painting behind glass can look
    // semantically identical to a monitor in one still frame. Do not promote
    // that semantic resemblance to STRONG display risk unless the ML result
    // also carries the strict dual-region spatial signature already used by
    // the fusion engine. The uploaded real-monitor control satisfies this
    // gate, while the reflective artwork false positive does not.
    if (predictedClass.startsWith('SCREEN_') &&
        screenProbability >= 0.95 &&
        confidence >= 0.90 &&
        hasSpatialScreenCorroboration(ml)) {
      final score = mlScore.clamp(85, 100).toInt();
      return HCVDisplayRiskResult(
        risk: 'HIGH',
        score: score,
        decision: 'STRONG_DISPLAY_RISK',
        analysisStatus: 'COMPLETE',
        evidenceSources: const ['ML_SCREEN_CLASS'],
        strongSources: const ['ML_SCREEN_CLASS'],
        reasons: const [
          'ML_FIRST_PHOTO_EXTREME_DUAL_REGION_SCREEN_EVIDENCE',
        ],
      );
    }
"""
photo_new = """    // Current classifiers provide independent full-frame and content-area
    // risk scores. A glossy print, framed artwork or other flat reflective
    // surface can receive a high SCREEN semantic probability while those two
    // regions do not agree strongly enough. When both diagnostics are present,
    // require that corroboration before ML alone can produce a strong verdict.
    // Older signed analyses that predate these fields retain the frozen 0.80
    // compatibility rule and are not reinterpreted retroactively.
    final mlSignals = _signals(ml);
    final hasMlFirstPhotoSpatialDiagnostics =
        mlSignals.containsKey('fullFrameRiskScore') &&
            mlSignals.containsKey('contentAreaRiskScore');
    final fullFrameRisk =
        (mlSignals['fullFrameRiskScore'] as num?)?.toInt() ?? 0;
    final contentAreaRisk =
        (mlSignals['contentAreaRiskScore'] as num?)?.toInt() ?? 0;
    final currentPhotoSpatialCorroboration =
        !hasMlFirstPhotoSpatialDiagnostics ||
            (fullFrameRisk >= 90 &&
                contentAreaRisk >= 85 &&
                (confidence == 0.0 || confidence >= 0.75));

    if (predictedClass.startsWith('SCREEN_') &&
        screenProbability >= 0.80 &&
        currentPhotoSpatialCorroboration) {
      final score = mlScore.clamp(80, 100).toInt();
      return HCVDisplayRiskResult(
        risk: 'HIGH',
        score: score,
        decision: 'STRONG_DISPLAY_RISK',
        analysisStatus: 'COMPLETE',
        evidenceSources: const ['ML_SCREEN_CLASS'],
        strongSources: const ['ML_SCREEN_CLASS'],
        reasons: hasMlFirstPhotoSpatialDiagnostics
            ? const [
                'ML_FIRST_PHOTO_SCREEN_FAMILY_HIGH_PROBABILITY',
                'ML_FIRST_PHOTO_SPATIAL_CORROBORATION',
              ]
            : const ['ML_FIRST_PHOTO_SCREEN_FAMILY_HIGH_PROBABILITY'],
      );
    }
"""
replace_once(
    'lib/hcv_display_risk_fusion.dart',
    photo_old,
    photo_new,
    'hasMlFirstPhotoSpatialDiagnostics',
)

video_old = """    // A screen-family majority is not sufficient by itself: a reflective flat
    // artwork can stay semantically screen-like across a short pan. Require the
    // existing multi-frame consistency gate (medium evidence in at least 75%
    // of frames, high aggregate/region scores and high probability). This keeps
    // the uploaded true monitor strong while rejecting the reflective artwork
    // and manuscript controls as ML-only false positives.
    if (screenMajority && hasMultiFrameScreenConsistency(ml)) {
      final score = mlScore.clamp(75, 100).toInt();
      return HCVDisplayRiskResult(
        risk: 'HIGH',
        score: score,
        decision: 'STRONG_DISPLAY_RISK',
        analysisStatus: 'COMPLETE',
        evidenceSources: const ['ML_SCREEN_CLASS'],
        strongSources: const ['ML_SCREEN_CLASS'],
        reasons: const ['ML_FIRST_VIDEO_MULTI_FRAME_SCREEN_CONSISTENCY'],
      );
    }
"""
video_new = """    // Preserve the legacy probability+semantic-majority rule for older ML
    // payloads. Current payloads expose aggregate/frame diagnostics as well;
    // when that complete diagnostic set is available, require it to agree with
    // the semantic majority. This separates the observed reflective artwork
    // (high semantic probability but low aggregate/frame support) from the
    // historical and current true-monitor controls.
    final mlSignals = _signals(ml);
    final hasMlFirstVideoDiagnostics =
        ml.containsKey('mediumScreenFrameCount') &&
            ml.containsKey('averageScreenReplayRiskScore') &&
            ml.containsKey('maxFrameScreenReplayRiskScore') &&
            mlSignals.containsKey('fullFrameRiskScore') &&
            mlSignals.containsKey('contentAreaRiskScore');
    final mediumScreenFrames =
        (ml['mediumScreenFrameCount'] as num?)?.toInt() ?? 0;
    final averageFrameScore =
        (ml['averageScreenReplayRiskScore'] as num?)?.toDouble() ?? 0.0;
    final maxFrameScore =
        (ml['maxFrameScreenReplayRiskScore'] as num?)?.toInt() ?? 0;
    final currentVideoDiagnosticCorroboration =
        !hasMlFirstVideoDiagnostics ||
            (mlScore >= 75 &&
                mediumScreenFrames * 2 >= framesAnalyzed &&
                averageFrameScore >= 80.0 &&
                maxFrameScore >= 90);

    if (screenMajority &&
        screenProbability >= 0.75 &&
        currentVideoDiagnosticCorroboration) {
      final score = mlScore.clamp(75, 100).toInt();
      return HCVDisplayRiskResult(
        risk: 'HIGH',
        score: score,
        decision: 'STRONG_DISPLAY_RISK',
        analysisStatus: 'COMPLETE',
        evidenceSources: const ['ML_SCREEN_CLASS'],
        strongSources: const ['ML_SCREEN_CLASS'],
        reasons: hasMlFirstVideoDiagnostics
            ? const [
                'ML_FIRST_VIDEO_SCREEN_MAJORITY_HIGH_PROBABILITY',
                'ML_FIRST_VIDEO_FRAME_DIAGNOSTIC_CORROBORATION',
              ]
            : const ['ML_FIRST_VIDEO_SCREEN_MAJORITY_HIGH_PROBABILITY'],
      );
    }
"""
replace_once(
    'lib/hcv_display_risk_fusion.dart',
    video_old,
    video_new,
    'hasMlFirstVideoDiagnostics',
)


# ---------------------------------------------------------------------------
# 2) Creator entitlement check race.
# Multiple resume/bootstrap/protected-action callers share the same in-flight
# verification Future instead of treating an already-running check as failure.
# ---------------------------------------------------------------------------
replace_once(
    'lib/user_home_page.dart',
    '  bool _entitlementCheckInFlight = false;\n',
    '  Future<bool>? _entitlementCheckInFlight;\n',
    'Future<bool>? _entitlementCheckInFlight',
)

entitlement_old = """  Future<bool> _revalidateCreatorEntitlement({
    bool blockProtectedAction = false,
  }) async {
    if (_routingToCommercialGate) return false;
    if (_entitlementCheckInFlight) return false;

    _entitlementCheckInFlight = true;
    try {
      final billing = await _account.billingStatus();
      final status = billing['status']?.toString() ?? 'inactive';
      final active = status == 'active' || status == 'grace';
      if (active) return true;

      _routeToCommercialGate();
      return false;
    } catch (error) {
      // A transient network/App Store error must not silently grant access to a
      // new Creator operation. Existing UI remains visible, but protected
      // certification actions stay blocked until entitlement can be verified.
      if (blockProtectedAction && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Impossibile verificare l’abbonamento Creator. Riprova quando la connessione è disponibile.',
            ),
          ),
        );
      }
      return false;
    } finally {
      _entitlementCheckInFlight = false;
    }
  }
"""
entitlement_new = """  Future<bool> _revalidateCreatorEntitlement({
    bool blockProtectedAction = false,
  }) async {
    if (_routingToCommercialGate) return false;

    final existingCheck = _entitlementCheckInFlight;
    if (existingCheck != null) {
      final active = await existingCheck;
      if (!active && blockProtectedAction && !_routingToCommercialGate) {
        _showEntitlementVerificationBlocked();
      }
      return active;
    }

    final check = _performCreatorEntitlementCheck();
    _entitlementCheckInFlight = check;
    try {
      final active = await check;
      if (!active && blockProtectedAction && !_routingToCommercialGate) {
        _showEntitlementVerificationBlocked();
      }
      return active;
    } finally {
      if (identical(_entitlementCheckInFlight, check)) {
        _entitlementCheckInFlight = null;
      }
    }
  }

  Future<bool> _performCreatorEntitlementCheck() async {
    try {
      final billing = await _account.billingStatus();
      final status = billing['status']?.toString() ?? 'inactive';
      final active = status == 'active' || status == 'grace';
      if (active) return true;

      _routeToCommercialGate();
      return false;
    } catch (_) {
      // Fail closed for new Creator operations when entitlement cannot be
      // verified. A concurrent caller will receive this same result.
      return false;
    }
  }

  void _showEntitlementVerificationBlocked() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Impossibile verificare l’abbonamento Creator. Riprova quando la connessione è disponibile.',
        ),
      ),
    );
  }
"""
replace_once(
    'lib/user_home_page.dart',
    entitlement_old,
    entitlement_new,
    'final existingCheck = _entitlementCheckInFlight',
)

print('Creator/reflective finalizer completed.')
