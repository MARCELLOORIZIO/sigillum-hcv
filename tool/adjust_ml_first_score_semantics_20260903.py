from pathlib import Path

# Final validation revision: retain legacy low-risk score semantics.
path = Path('lib/camera_page.dart')
text = path.read_text()
old = """  return HCVDisplayRiskResult(
    risk: primary.risk,
    score: primary.score,
    decision: primary.decision,
"""
new = """  final finalScore = primary.decision == 'NO_DISPLAY_EVIDENCE'
      ? diagnostics.score.clamp(primary.score, 20).toInt()
      : primary.score;

  return HCVDisplayRiskResult(
    risk: primary.risk,
    score: finalScore,
    decision: primary.decision,
"""
count = text.count(old)
if count != 1:
    raise SystemExit(f'expected one ML-primary result merge, found {count}')
path.write_text(text.replace(old, new, 1))
print('ML-first score semantics adjusted')
