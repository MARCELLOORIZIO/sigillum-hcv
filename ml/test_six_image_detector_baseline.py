"""Unit tests for the six-photo diagnostic baseline checker (no images needed)."""
import unittest

from check_six_image_detector_baseline import EXPECTED, check


def sample():
    return {
        "type": "SIGILLUM_YOLO_REFERENCE_ONLY",
        "confidenceThreshold": 0.25,
        "iouThreshold": 0.7,
        "images": [
            {"image": f"hcv_photo_HCV-{case}.JPG",
             "models": {
                 "screen_detection": {"detections": [{}] * counts[0]},
                 "phone_device_v4": {"detections": [{}] * counts[1]},
             }}
            for case, counts in EXPECTED.items()
        ],
    }


class BaselineTests(unittest.TestCase):
    def test_expected_observations(self):
        self.assertEqual(check(sample()), [])

    def test_missing_image_is_detected(self):
        data = sample()
        data["images"].pop()
        self.assertTrue(any("Missing case" in e for e in check(data)))

    def test_changed_detector_output_is_detected(self):
        data = sample()
        data["images"][0]["models"]["phone_device_v4"]["detections"].append({})
        self.assertTrue(check(data))

    def test_duplicate_case_is_detected(self):
        data = sample()
        data["images"].append(data["images"][0])
        self.assertTrue(any("Duplicate HCV case" in e for e in check(data)))

    def test_changed_thresholds_are_detected(self):
        data = sample()
        data["confidenceThreshold"] = 0.5
        self.assertTrue(any("threshold mismatch" in e for e in check(data)))


if __name__ == "__main__":
    unittest.main()
