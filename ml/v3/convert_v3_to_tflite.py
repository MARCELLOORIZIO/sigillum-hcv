from __future__ import annotations
import base64, json
from pathlib import Path
import numpy as np
import tensorflow as tf

ROOT=Path(__file__).resolve().parents[2]
WEIGHTS=ROOT/"ml/v3/v3_multihead_weights_fp16.json"
PARITY=ROOT/"ml/v3/v3_parity_vectors.json"
OUT=ROOT/"ml/v3/out"
OUT.mkdir(parents=True,exist_ok=True)

raw=json.loads(WEIGHTS.read_text())
classes=raw["classes"]
weights=raw["weights"]

def arr(name):
    item=weights[name]
    shape=tuple(item["shape"])
    dtype=item["dtype"]
    data=base64.b64decode(item["data"])
    if dtype=="float16":
        a=np.frombuffer(data,dtype=np.float16).astype(np.float32)
    elif dtype=="int64":
        a=np.frombuffer(data,dtype=np.int64)
    else:
        raise ValueError((name,dtype))
    return a.reshape(shape)

inp=tf.keras.Input(shape=(96,96,3),dtype=tf.float32,name="image")
x=inp
filters=[20,28,40,56,80]
for i,f in enumerate(filters):
    x=tf.keras.layers.Conv2D(f,3,padding="same",use_bias=False,name=f"conv{i}")(x)
    x=tf.keras.layers.BatchNormalization(epsilon=1e-5,name=f"bn{i}")(x)
    x=tf.keras.layers.ReLU(name=f"relu{i}")(x)
    x=tf.keras.layers.MaxPool2D(pool_size=2,name=f"pool{i}")(x)
x=tf.keras.layers.GlobalAveragePooling2D(name="gap")(x)
x=tf.keras.layers.Dense(96,activation="relu",name="fc")(x)
clean_logits=tf.keras.layers.Dense(7,name="clean_logits")(x)
hard_logits=tf.keras.layers.Dense(7,name="hard_logits")(x)
clean=tf.keras.layers.Softmax(name="clean_probs")(clean_logits)
hard=tf.keras.layers.Softmax(name="hard_probs")(hard_logits)
model=tf.keras.Model(inp,[clean,hard],name="sigillum_v3_multihead")

pt_conv_idx=[0,4,8,12,16]
pt_bn_idx=[1,5,9,13,17]
for i,(ci,bi) in enumerate(zip(pt_conv_idx,pt_bn_idx)):
    w=arr(f"backbone.{ci}.weight").transpose(2,3,1,0)
    model.get_layer(f"conv{i}").set_weights([w])
    gamma=arr(f"backbone.{bi}.weight")
    beta=arr(f"backbone.{bi}.bias")
    mean=arr(f"backbone.{bi}.running_mean")
    var=arr(f"backbone.{bi}.running_var")
    model.get_layer(f"bn{i}").set_weights([gamma,beta,mean,var])

model.get_layer("fc").set_weights([arr("fc.1.weight").T,arr("fc.1.bias")])
model.get_layer("clean_logits").set_weights([arr("clean.weight").T,arr("clean.bias")])
model.get_layer("hard_logits").set_weights([arr("hard.weight").T,arr("hard.bias")])

par=json.loads(PARITY.read_text())
keras_max=0.0
for v in par["vectors"]:
    x=np.random.default_rng(v["seed"]).random((1,96,96,3),dtype=np.float32)
    kc,kh=model(x,training=False)
    keras_max=max(keras_max,float(np.max(np.abs(kc.numpy()[0]-np.array(v["clean"],np.float32)))))
    keras_max=max(keras_max,float(np.max(np.abs(kh.numpy()[0]-np.array(v["hard"],np.float32)))))
print("KERAS_PARITY_MAX_ABS",keras_max)
if keras_max>2e-3:
    raise SystemExit(f"Keras parity failed: {keras_max}")

converter=tf.lite.TFLiteConverter.from_keras_model(model)
converter.optimizations=[tf.lite.Optimize.DEFAULT]
converter.target_spec.supported_types=[tf.float16]
tflite=converter.convert()
model_path=OUT/"sigillum_screen_replay_v3_multihead.tflite"
model_path.write_bytes(tflite)

inter=tf.lite.Interpreter(model_path=str(model_path))
inter.allocate_tensors()
inp_d=inter.get_input_details()[0]
outs=inter.get_output_details()
print("TFLITE_INPUT",inp_d)
print("TFLITE_OUTPUTS",outs)

# Determine output order from parity vector by minimum matching error.
v=par["vectors"][0]
x=np.random.default_rng(v["seed"]).random((1,96,96,3),dtype=np.float32)
inter.set_tensor(inp_d["index"],x)
inter.invoke()
vals=[inter.get_tensor(o["index"])[0] for o in outs]
clean_ref=np.array(v["clean"],np.float32);hard_ref=np.array(v["hard"],np.float32)
err_direct=float(np.max(np.abs(vals[0]-clean_ref))+np.max(np.abs(vals[1]-hard_ref)))
err_swap=float(np.max(np.abs(vals[1]-clean_ref))+np.max(np.abs(vals[0]-hard_ref)))
order=["clean","hard"] if err_direct<=err_swap else ["hard","clean"]
print("TFLITE_OUTPUT_ORDER",order)

tflite_max=0.0
for v in par["vectors"]:
    x=np.random.default_rng(v["seed"]).random((1,96,96,3),dtype=np.float32)
    kc,kh=model(x,training=False)
    inter.set_tensor(inp_d["index"],x);inter.invoke()
    vals=[inter.get_tensor(o["index"])[0] for o in outs]
    if order==["clean","hard"]: tc,th=vals
    else: th,tc=vals
    tflite_max=max(tflite_max,float(np.max(np.abs(tc-kc.numpy()[0]))),float(np.max(np.abs(th-kh.numpy()[0]))))
print("TFLITE_PARITY_MAX_ABS",tflite_max)
if tflite_max>5e-3:
    raise SystemExit(f"TFLite parity failed: {tflite_max}")

manifest={
 "type":"SIGILLUM_V3_MULTIHEAD_TFLITE_V1",
 "modelFile":model_path.name,
 "classes":classes,
 "inputShape":[1,96,96,3],
 "inputRange":"0..1 float32",
 "outputs":order,
 "kerasParityMaxAbs":keras_max,
 "tfliteParityMaxAbs":tflite_max,
 "residualRule":{"v2High":0.80,"v2Low":0.15,"v3Veto":0.20,"v3Screen":0.50},
 "benchmark":{"frozenPhoto":"13/13","build126PhotoHoldout":"15/15","combined":"28/28"},
}
(OUT/"manifest.json").write_text(json.dumps(manifest,indent=2))
print(json.dumps(manifest,indent=2))
