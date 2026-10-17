import unittest
from check_flutter_yolo_parity import evaluate


class ParityContractTests(unittest.TestCase):
    def setUp(self):
        self.ref = {
            "type": "SIGILLUM_YOLO_REFERENCE_ONLY",
            "images": [{"image": "case.jpg", "imageSha256": "image1",
                        "models": {"phone_device_v4": {
                            "modelSha256": "model1",
                            "detections": [{"class": "PHONE_DEVICE", "score": 0.9,
                                            "xyxy": [10.0, 20.0, 40.0, 50.0]}]}}}]
        }
        self.dart = {
            "type": "SIGILLUM_YOLO_FLUTTER_PARITY",
            "images": [{"imageSha256": "image1", "models": {
                "phone_device_v4": {"analysisStatus": "ANALYZED",
                                    "modelSha256": "model1",
                                    "detections": [{"class": "PHONE_DEVICE",
                                                    "confidence": 0.9,
                                                    "boxXYXY": [10.1, 20.1, 40.1, 50.1]}]}}}]
        }

    def test_matching_boxes(self):
        self.assertEqual(evaluate(self.ref, self.dart), [])

    def test_missing_real_flutter_inference_rejected(self):
        self.dart["images"][0]["models"]["phone_device_v4"]["analysisStatus"] = "NOT_ANALYZED"
        self.assertTrue(evaluate(self.ref, self.dart))

    def test_model_hash_mismatch_rejected(self):
        self.dart["images"][0]["models"]["phone_device_v4"]["modelSha256"] = "other"
        self.assertTrue(evaluate(self.ref, self.dart))

    def test_bad_geometry_rejected(self):
        self.dart["images"][0]["models"]["phone_device_v4"]["detections"][0]["boxXYXY"][0] = 30
        self.assertTrue(evaluate(self.ref, self.dart))

    def test_image_hash_mismatch_rejected(self):
        self.dart["images"][0]["imageSha256"] = "other"
        self.assertTrue(evaluate(self.ref, self.dart))


if __name__ == "__main__":
    unittest.main()
