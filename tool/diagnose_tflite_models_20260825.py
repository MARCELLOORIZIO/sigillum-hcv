from __future__ import annotations

import hashlib
from collections import Counter
from pathlib import Path

import tensorflow as tf

MODELS = [
    Path('assets/ml/sigillum_screen_replay_v2.tflite'),
    Path('assets/ml/sigillum_screen_replay_v1.tflite'),
]

print(f'TENSORFLOW_VERSION={tf.__version__}')
print('TFLITE_DIAGNOSTIC_BEGIN')

failures: list[str] = []
for model_path in MODELS:
    raw = model_path.read_bytes()
    digest = hashlib.sha256(raw).hexdigest()
    print(f'MODEL={model_path}')
    print(f'SIZE={len(raw)} SHA256={digest}')
    try:
        interpreter = tf.lite.Interpreter(model_path=str(model_path))
        interpreter.allocate_tensors()
        inputs = interpreter.get_input_details()
        outputs = interpreter.get_output_details()
        print(f'INTERPRETER_CREATE=PASS INPUTS={inputs} OUTPUTS={outputs}')
        try:
            ops = interpreter._get_ops_details()  # Diagnostic only.
        except Exception as exc:
            print(f'OPS_READ=UNAVAILABLE {type(exc).__name__}: {exc}')
            ops = []
        counts = Counter(str(item.get('op_name', 'UNKNOWN')) for item in ops)
        print('OPS=' + ','.join(f'{name}:{count}' for name, count in sorted(counts.items())))
        flex = sorted(name for name in counts if name.startswith('Flex'))
        print('FLEX_OPS=' + (','.join(flex) if flex else 'NONE'))
    except Exception as exc:
        failures.append(f'{model_path}: {type(exc).__name__}: {exc}')
        print(f'INTERPRETER_CREATE=FAIL {type(exc).__name__}: {exc}')
    print('---')

print('TFLITE_DIAGNOSTIC_END')
if failures:
    raise SystemExit(' | '.join(failures))
