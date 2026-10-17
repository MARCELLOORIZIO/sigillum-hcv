import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_phone_device_v4_contract.dart';

void main() {
  group('V4 diagnostic tensor contract', () {
    test('accepts only observed float32 NCHW and raw YOLO output', () {
      expect(
        HCVPhoneDeviceV4Contract.matches(
          actualInputShape: [1, 3, 416, 416],
          actualOutputShape: [1, 5, 3549],
          inputType: 'float32',
          outputType: 'float32',
        ),
        isTrue,
      );
      expect(
        HCVPhoneDeviceV4Contract.matches(
          actualInputShape: [1, 416, 416, 3],
          actualOutputShape: [1, 5, 3549],
          inputType: 'float32',
          outputType: 'float32',
        ),
        isFalse,
      );
      expect(
        HCVPhoneDeviceV4Contract.matches(
          actualInputShape: [1, 3, 416, 416],
          actualOutputShape: [1, 3549, 5],
          inputType: 'float32',
          outputType: 'float32',
        ),
        isFalse,
      );
      expect(
        HCVPhoneDeviceV4Contract.matches(
          actualInputShape: [1, 3, 416, 416],
          actualOutputShape: [1, 5, 3549],
          inputType: 'uint8',
          outputType: 'float32',
        ),
        isFalse,
      );
    });

    test('missing model has explicit unavailability, not a clean scene', () {
      final status = HCVPhoneDeviceV4Contract.diagnosticStatus(
        modelAvailable: false,
      );
      expect(status['analysisStatus'], 'NOT_ANALYZED');
      expect(status['decisionRole'], 'DIAGNOSTIC_ONLY');
      expect(status['devicePresent'], isNull);
      expect(status['screenReplayRiskDecision'], isNull);
      expect(status['physicalRecaptureProven'], isFalse);
    });

    test('verified tensor contract is not a detection or verdict', () {
      final status = HCVPhoneDeviceV4Contract.diagnosticStatus(
        modelAvailable: true,
        actualInputShape: [1, 3, 416, 416],
        actualOutputShape: [1, 5, 3549],
        inputType: 'float32',
        outputType: 'float32',
      );
      expect(status['analysisStatus'], 'CONTRACT_VERIFIED');
      expect(status['devicePresent'], isNull);
      expect(status['screenReplayRiskDecision'], isNull);
      expect(status['reason'], 'TENSOR_CONTRACT_ONLY_NO_INFERENCE');
    });
  });
}
