from pathlib import Path

path = Path('test/hfr_v32_harmonic_reality_physics_test.dart')
text = path.read_text()
text = text.replace("package:sigillum_hcv/hcv_display_risk_fusion.dart", "package:sigillum_iphone/hcv_display_risk_fusion.dart")
text = text.replace("package:sigillum_hcv/hcv_temporal_frequency_probe.dart", "package:sigillum_iphone/hcv_temporal_frequency_probe.dart")
path.write_text(text)
print('BUILD108 test imports corrected')
