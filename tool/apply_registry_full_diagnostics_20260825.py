from pathlib import Path

path = Path('lib/registry_verify_page.dart')
source = path.read_text(encoding='utf-8')

# Presentation-only: expose the technical evidence already present in the
# signed certificate. No verification decision or certificate content changes.
if 'String get _fullTechnicalDiagnostics' not in source:
    anchor = '  @override\n  Widget build(BuildContext context) {\n'
    if anchor not in source:
        raise RuntimeError('Registry build anchor missing for full diagnostics')
    helper = r'''  Map<dynamic, dynamic>? get _signedMlDiagnostics {
    final cert = certificate;
    final claims = cert?['claims'];
    if (claims is! Map) return null;
    final ml = claims['mlScreenReplayAnalysis'];
    return ml is Map ? ml : null;
  }

  String _diagnosticValue(Object? value) {
    final text = value?.toString();
    return text == null || text.isEmpty ? '-' : text;
  }

  String get _fullTechnicalDiagnostics {
    final ml = _signedMlDiagnostics;
    return 'HCV trust: ${_diagnosticValue(hcvTrustLevel)}\n'
        'Live capture trust: ${_diagnosticValue(liveCaptureTrust)}\n'
        'Scene authenticity: ${_diagnosticValue(sceneAuthenticity)}\n'
        'Synthetic risk: ${_diagnosticValue(syntheticRisk)}\n'
        'AI proof level: ${_diagnosticValue(aiProofLevel)}\n'
        '\nDISPLAY FUSION\n'
        'Decision: ${_diagnosticValue(displayRiskDecision)}\n'
        'Risk: ${_diagnosticValue(screenReplayRisk)}\n'
        'Score: ${_diagnosticValue(screenReplayRiskScore)}\n'
        '\nPASSIVE VIDEO/IMAGE ANALYSIS\n'
        'Segments analyzed: ${_diagnosticValue(screenReplaySegmentsAnalyzed)}\n'
        'Worst segment second: ${_diagnosticValue(screenReplayWorstSecond)}\n'
        'Local temporal flicker: ${_diagnosticValue(localTemporalFlickerScore)}\n'
        'Refresh band: ${_diagnosticValue(refreshBandScore)}\n'
        'Pixel-grid uniformity: ${_diagnosticValue(pixelGridUniformityScore)}\n'
        '\nLIVE SCREEN PROBE\n'
        'Analysis status: ${_diagnosticValue(liveProbeAnalysisStatus)}\n'
        'Frames analyzed: ${_diagnosticValue(liveProbeFrames)}\n'
        'Risk: ${_diagnosticValue(liveProbeRisk)}\n'
        'Reason: ${_diagnosticValue(liveProbeReason)}\n'
        'Error: ${_diagnosticValue(liveProbeError)}\n'
        'Local temporal flicker: ${_diagnosticValue(liveProbeLocalFlickerScore)}\n'
        'Refresh band: ${_diagnosticValue(liveProbeRefreshBandScore)}\n'
        'Fine stripe: ${_diagnosticValue(liveProbeFineStripeScore)}\n'
        'Fine grid: ${_diagnosticValue(liveProbeFineGridScore)}\n'
        'Moiré frequency: ${_diagnosticValue(liveProbeMoireFrequencyScore)}\n'
        'Dynamic challenge: ${_diagnosticValue(liveProbeDynamicChallengeScore)}\n'
        'Persistent pattern: ${_diagnosticValue(liveProbePersistentPatternScore)}\n'
        'Optical corroborated trace: ${_diagnosticValue(liveProbeOpticalCorroboratedTrace)}\n'
        'Moiré trace: ${_diagnosticValue(liveProbeMoireFrequencyTrace)}\n'
        'Dynamic screen challenge trace: ${_diagnosticValue(liveProbeDynamicScreenChallengeTrace)}\n'
        'Uncorroborated display pattern: ${_diagnosticValue(liveProbeUncorroboratedDisplayPattern)}\n'
        '\nML SCREEN REPLAY\n'
        'Analysis status: ${_diagnosticValue(ml?['analysisStatus'])}\n'
        'Model source: ${_diagnosticValue(ml?['modelSource'])}\n'
        'Model version: ${_diagnosticValue(ml?['modelVersion'])}\n'
        'TFLite runtime: ${_diagnosticValue(ml?['tfliteRuntimeVersion'])}\n'
        'Model SHA-256: ${_diagnosticValue(ml?['modelSha256'])}\n'
        'Predicted class: ${_diagnosticValue(ml?['predictedClass'])}\n'
        'Predicted confidence: ${_diagnosticValue(ml?['predictedClassConfidence'])}\n'
        'Screen probability: ${_diagnosticValue(ml?['screenProbability'])}\n'
        'Risk: ${_diagnosticValue(ml?['screenReplayRisk'])}\n'
        'Risk score: ${_diagnosticValue(ml?['screenReplayRiskScore'])}\n'
        'ML decision: ${_diagnosticValue(ml?['displayRiskDecision'])}\n'
        'Reason: ${_diagnosticValue(ml?['reason'])}\n'
        'Error: ${_diagnosticValue(ml?['error'])}';
  }

'''
    source = source.replace(anchor, helper + anchor, 1)

# The 24/08 finalizer intentionally reduced the disclosure to five lines.
# Replace only that display text; keep the ExpansionTile collapsed by default.
start_marker = "                      Text(\n                        'HCV: ${hcvTrustLevel ?? '-'}\\n'"
start = source.find(start_marker)
if start >= 0:
    end_marker = "                      ),\n                    ],"
    end = source.find(end_marker, start)
    if end < 0:
        raise RuntimeError('compact technical diagnostic block end missing')
    replacement = r'''                      Text(
                        _fullTechnicalDiagnostics,
                        textAlign: TextAlign.left,
                        style: const TextStyle(
                          color: SigillumTheme.muted,
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
'''
    source = source[:start] + replacement + source[end + len("                      ),\n"):]
elif '_fullTechnicalDiagnostics,' not in source:
    raise RuntimeError('compact technical diagnostic block not found')

required = [
    'String get _fullTechnicalDiagnostics',
    "claims['mlScreenReplayAnalysis']",
    "'TFLite runtime: ${_diagnosticValue(ml?['tfliteRuntimeVersion'])}",
    "'Fine stripe: ${_diagnosticValue(liveProbeFineStripeScore)}",
    "'Pixel-grid uniformity: ${_diagnosticValue(pixelGridUniformityScore)}",
    '_fullTechnicalDiagnostics,',
]
for token in required:
    if token not in source:
        raise RuntimeError(f'full Registry diagnostic token missing: {token}')

path.write_text(source, encoding='utf-8')
print('Registry technical disclosure restored with complete signed diagnostics')
