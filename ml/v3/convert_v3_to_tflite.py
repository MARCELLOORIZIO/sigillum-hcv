from __future__ import annotations
import base64, json
from pathlib import Path
from itertools import permutations
import numpy as np
import tensorflow as tf

ROOT=Path(__file__).resolve().parents[2]
WEIGHTS=ROOT/"ml/v3/v3_multihead_weights_fp16.json"
PARITY=ROOT/"ml/v3/v3_parity_vectors.json"
HARD_NEGATIVE=ROOT/"ml/v3/v3_hard_negative_head_172a_fp16.json"
OUT=ROOT/"ml/v3/out"
OUT.mkdir(parents=True,exist_ok=True)

raw=json.loads(WEIGHTS.read_text())
classes=raw["classes"]
weights=raw["weights"]
hard_negative_raw=json.loads(HARD_NEGATIVE.read_text())
hard_negative_weights=hard_negative_raw["weights"]
hard_negative_threshold=float(hard_negative_raw["threshold"])

def arr(name, source=None):
    source = weights if source is None else source
    item=source[name]
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
hn_hidden=tf.keras.layers.Dense(
    int(hard_negative_raw["hiddenSize"]),
    activation="relu",
    name="hard_negative_fc",
)(x)
hn_logit=tf.keras.layers.Dense(1,name="hard_negative_logit")(hn_hidden)
hard_negative_reality=tf.keras.layers.Activation(
    "sigmoid",
    name="hard_negative_reality_probability",
)(hn_logit)
model=tf.keras.Model(
    inp,
    [clean,hard,hard_negative_reality],
    name="sigillum_v3_multihead_hardnegative",
)

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
model.get_layer("hard_negative_fc").set_weights([
    arr("fc.weight", hard_negative_weights).T,
    arr("fc.bias", hard_negative_weights),
])
model.get_layer("hard_negative_logit").set_weights([
    arr("out.weight", hard_negative_weights).T,
    arr("out.bias", hard_negative_weights),
])

par=json.loads(PARITY.read_text())
keras_max=0.0
for v in par["vectors"]:
    x=np.random.default_rng(v["seed"]).random((1,96,96,3),dtype=np.float32)
    kc,kh,_=model(x,training=False)
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

# Determine the three-output order by minimum error against Keras.
v=par["vectors"][0]
x=np.random.default_rng(v["seed"]).random((1,96,96,3),dtype=np.float32)
kc,kh,kn=model(x,training=False)
refs={
    "clean":kc.numpy()[0],
    "hard":kh.numpy()[0],
    "hardNegativeReality":kn.numpy()[0],
}
inter.set_tensor(inp_d["index"],x)
inter.invoke()
vals=[inter.get_tensor(o["index"])[0] for o in outs]
labels=["clean","hard","hardNegativeReality"]
best=None
for perm in permutations(labels):
    err=0.0
    for i,label in enumerate(perm):
        err+=float(np.max(np.abs(vals[i]-refs[label])))
    if best is None or err<best[0]:
        best=(err,list(perm))
order=best[1]
print("TFLITE_OUTPUT_ORDER",order)

tflite_max=0.0
for v in par["vectors"]:
    x=np.random.default_rng(v["seed"]).random((1,96,96,3),dtype=np.float32)
    kc,kh,kn=model(x,training=False)
    refs={
        "clean":kc.numpy()[0],
        "hard":kh.numpy()[0],
        "hardNegativeReality":kn.numpy()[0],
    }
    inter.set_tensor(inp_d["index"],x);inter.invoke()
    vals=[inter.get_tensor(o["index"])[0] for o in outs]
    for i,label in enumerate(order):
        tflite_max=max(
            tflite_max,
            float(np.max(np.abs(vals[i]-refs[label]))),
        )
print("TFLITE_PARITY_MAX_ABS",tflite_max)
if tflite_max>5e-3:
    raise SystemExit(f"TFLite parity failed: {tflite_max}")

manifest={
 "type":"SIGILLUM_V3_MULTIHEAD_TFLITE_V2_HARD_NEGATIVE",
 "modelFile":model_path.name,
 "classes":classes,
 "inputShape":[1,96,96,3],
 "inputRange":"0..1 float32",
 "outputs":order,
 "hardNegativeHead":{
   "type":hard_negative_raw["type"],
   "hardNegativeHcvId":hard_negative_raw["hardNegativeHcvId"],
   "hardNegativeSha256":hard_negative_raw["hardNegativeSha256"],
   "threshold":hard_negative_threshold,
   "inputFeatureSize":hard_negative_raw["inputFeatureSize"],
   "hiddenSize":hard_negative_raw["hiddenSize"],
   "externalGate":hard_negative_raw["externalGate"],
 },
 "kerasParityMaxAbs":keras_max,
 "tfliteParityMaxAbs":tflite_max,
 "benchmarkRule":{
   "v2High":0.80,
   "v2Low":0.15,
   "v3Veto":0.25,
   "v3Screen":0.50
 },
 "productionResidualPolicy":{
   "role":"PHOTO_V2_FALSE_POSITIVE_VETO_ONLY",
   "v2High":0.80,
   "v3RealityVeto":0.20,
   "hardNegativeRealityThreshold":hard_negative_threshold,
   "hardNegativeRole":"PHOTO_STRONG_V2_FALSE_POSITIVE_VETO_ONLY",
   "screenPromotion":False,
   "affectsVideo":False
 },
 "benchmark":{"frozenPhoto":"13/13","build126PhotoHoldout":"15/15","combined":"28/28"},
}
(OUT/"manifest.json").write_text(json.dumps(manifest,indent=2))
print(json.dumps(manifest,indent=2))
