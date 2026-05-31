from __future__ import annotations

import argparse
import json
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dataset", default="ml_work/dataset")
    parser.add_argument("--out", default="assets/ml/sigillum_screen_replay_v1.tflite")
    parser.add_argument("--epochs", type=int, default=18)
    parser.add_argument("--batch-size", type=int, default=16)
    parser.add_argument("--image-size", type=int, default=224)
    args = parser.parse_args()

    try:
        import tensorflow as tf
    except ImportError as exc:
        raise SystemExit(
            "TensorFlow non e' installato. Usa Python 3.11/3.12 e installa "
            "i pacchetti in ml/requirements.txt."
        ) from exc

    dataset = Path(args.dataset)
    labels = json.loads((dataset / "labels.json").read_text(encoding="utf-8"))
    class_names = labels["classes"]

    train = tf.keras.utils.image_dataset_from_directory(
        dataset / "train",
        labels="inferred",
        label_mode="categorical",
        class_names=class_names,
        image_size=(args.image_size, args.image_size),
        batch_size=args.batch_size,
        shuffle=True,
        seed=1337,
    )
    val = tf.keras.utils.image_dataset_from_directory(
        dataset / "val",
        labels="inferred",
        label_mode="categorical",
        class_names=class_names,
        image_size=(args.image_size, args.image_size),
        batch_size=args.batch_size,
        shuffle=False,
    )

    autotune = tf.data.AUTOTUNE
    train = train.prefetch(autotune)
    val = val.prefetch(autotune)

    augment = tf.keras.Sequential(
        [
            tf.keras.layers.RandomFlip("horizontal"),
            tf.keras.layers.RandomRotation(0.03),
            tf.keras.layers.RandomZoom(0.08),
            tf.keras.layers.RandomContrast(0.12),
        ],
        name="sigillum_augmentation",
    )

    base = tf.keras.applications.MobileNetV3Small(
        input_shape=(args.image_size, args.image_size, 3),
        include_top=False,
        weights="imagenet",
        pooling="avg",
    )
    base.trainable = False

    inputs = tf.keras.Input(shape=(args.image_size, args.image_size, 3))
    augmented = augment(inputs)
    x = tf.keras.applications.mobilenet_v3.preprocess_input(augmented)
    x = base(x, training=False)
    dropout = tf.keras.layers.Dropout(0.25)
    classifier = tf.keras.layers.Dense(len(class_names), activation="softmax")
    x = dropout(x)
    outputs = classifier(x)
    model = tf.keras.Model(inputs, outputs)

    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=0.001),
        loss="categorical_crossentropy",
        metrics=["accuracy"],
    )
    model.fit(train, validation_data=val, epochs=args.epochs)

    base.trainable = True
    for layer in base.layers[:-24]:
        layer.trainable = False
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=0.00008),
        loss="categorical_crossentropy",
        metrics=["accuracy"],
    )
    model.fit(train, validation_data=val, epochs=max(4, args.epochs // 3))

    inference_inputs = tf.keras.Input(shape=(args.image_size, args.image_size, 3))
    x = tf.keras.applications.mobilenet_v3.preprocess_input(inference_inputs)
    x = base(x, training=False)
    x = dropout(x, training=False)
    inference_outputs = classifier(x)
    inference_model = tf.keras.Model(inference_inputs, inference_outputs)

    saved_model = Path("ml_work/saved_model")
    saved_model.parent.mkdir(parents=True, exist_ok=True)
    inference_model.export(saved_model)

    converter = tf.lite.TFLiteConverter.from_saved_model(str(saved_model))
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_model = converter.convert()

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(tflite_model)
    (out.parent / "sigillum_screen_replay_v1_labels.json").write_text(
        json.dumps({"classes": class_names}, indent=2),
        encoding="utf-8",
    )
    print(f"TFLite scritto in {out}")


if __name__ == "__main__":
    main()
