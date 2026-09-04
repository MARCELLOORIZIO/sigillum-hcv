from pathlib import Path

path = Path('tool/apply_native_temporal_frequency_v2.py')
text = path.read_text()

early = """camera = camera.replace(\n    '    pendingTemporalFrequencyClip = null;\\n',\n    '',\n)\n\n"""
if text.count(early) != 1:
    raise SystemExit(f'early pending clip cleanup block count={text.count(early)}')
text = text.replace(early, '', 1)

marker = "camera_path.write_text(camera)\n"
late = """camera = camera.replace(\n    '    pendingTemporalFrequencyClip = null;\\n',\n    '',\n)\ncamera = camera.replace(\n    '    const frequencyProbeEngine = HCVTemporalFrequencyProbe();\\n',\n    '',\n)\n\n"""
if text.count(marker) != 1:
    raise SystemExit(f'camera write marker count={text.count(marker)}')
text = text.replace(marker, late + marker, 1)
path.write_text(text)
