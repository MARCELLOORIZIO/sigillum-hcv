from pathlib import Path
for name in ['test/illumination_response_probe_math_test.dart','test/physical_display_fusion_v1_test.dart']:
    p=Path(name)
    s=p.read_text().replace('package:sigillum_hcv/','package:sigillum_iphone/')
    p.write_text(s)
print('V1 test package imports fixed')
