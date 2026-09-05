from pathlib import Path

p = Path('ios/Runner/AppDelegate.swift')
s = p.read_text()
old = '''        try captureDevice.lockForConfiguration()\n        try captureDevice.setTorchModeOn(level: torchLevel)\n        captureDevice.unlockForConfiguration()\n'''
new = '''        try captureDevice.lockForConfiguration()\n        do {\n          try captureDevice.setTorchModeOn(level: torchLevel)\n          captureDevice.unlockForConfiguration()\n        } catch {\n          captureDevice.unlockForConfiguration()\n          throw error\n        }\n'''
if s.count(old) != 1:
    raise SystemExit(f'expected one torch-on lock block, found {s.count(old)}')
s = s.replace(old, new, 1)
p.write_text(s)
print('torch configuration error handling hardened')
