from pathlib import Path

path = Path('lib/registry_verify_page.dart')
source = path.read_text(encoding='utf-8')

# Replace either the legacy giant diagnostic dump or the intermediate wrapped
# version with one compact, collapsed technical disclosure. The public result
# remains the four understandable verification axes.
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
                        'HCV: ${hcvTrustLevel ?? '-'}\n'
                        '${_v('scene')}: ${_localizedAxisState('scene', _effectiveSceneState)}\n'
                        'Display: ${displayRiskDecision ?? '-'} / ${screenReplayRisk ?? '-'} / ${screenReplayRiskScore ?? '-'}\n'
                        'Live probe: ${liveProbeAnalysisStatus ?? '-'} / ${liveProbeRisk ?? '-'}\n'
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

# Ensure the public cards are light, rounded and visually coherent with the
# landing/account pages. This acts after older visual patchers.
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
    '_signedRealityScene',
]:
    if token not in source:
        raise RuntimeError(f'Registry final UI token missing: {token}')

path.write_text(source, encoding='utf-8')
print('Registry verification finalized with light cards, concise axes and collapsed technical details')
