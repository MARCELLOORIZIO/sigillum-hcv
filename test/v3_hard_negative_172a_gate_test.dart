import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_ml_v3_photo_residual.dart';

void main() {
  test('172A hard-negative head vetoes reality without losing frozen screens', () {
    const screens = <_Case>[
      _Case('HCV-88CC6F97F38A4D65', 0.992, 0.95361328125, 0.9200780391693115, 0.012978795915842056),
      _Case('HCV-49FA17D6D28E4688', 0.9892, 0.9624758958816528, 0.9334141612052917, 0.00011859625374199823),
      _Case('HCV-22ADB79B73BD4FBB', 0.9929, 0.9101839661598206, 0.8676363229751587, 5.6742908782325685e-05),
      _Case('HCV-66B58B42B999416A', 0.9993, 0.9602007269859314, 0.9305519461631775, 0.0002631013048812747),
      _Case('HCV-27463957577E4ED5', 0.9716, 0.9859651923179626, 0.9667825698852539, 2.0702400433947332e-06),
      _Case('HCV-D0DFF784C2D446DF', 0.9377, 0.967316746711731, 0.935002326965332, 1.6482810679008253e-05),
      _Case('HCV-AE0F458640004FE7', 0.9972, 0.9738003611564636, 0.9533980488777161, 4.837451342609711e-05),
      _Case('HCV-6A5B55785D2C4D9E', 0.9633, 0.2361750602722168, 0.2969628572463989, 0.1671850085258484),
      _Case('HCV-C6FA3CBBD5714382', 0.9979, 0.9724547863006592, 0.947705090045929, 1.855767806091535e-07),
      _Case('HCV-D516E077C10140D9', 0.9633, 0.978363037109375, 0.9574484825134277, 3.969869988296182e-10),
      _Case('HCV-C6C696A6E63344DF', 0.9937, 0.8117442727088928, 0.7490252256393433, 3.428109209835384e-07),
      _Case('HCV-E9F75F00F6134AF7', 0.9754, 0.3049117624759674, 0.3119840919971466, 0.9141342639923096),
      _Case('HCV-C8C399E3E9BE4B86', 0.9845, 0.8976732492446899, 0.8225351572036743, 1.4751586832062458e-06),
      _Case('HCV-BF1B0754CA594555', 0.8943, 0.9727423787117004, 0.9627377390861511, 8.01301098363183e-07),
      _Case('HCV-AEAFD4855C0B416E', 0.4038, 0.5257915258407593, 0.6034101843833923, 0.032956719398498535),
      _Case('HCV-E7F4F3D3456A4AE1', 0.3723, 0.9904847145080566, 0.9865924119949341, 4.480993354150087e-09),
      _Case('HCV-BD06C9FD69284BB6', 0.9265, 0.24100419878959656, 0.26623255014419556, 0.9747834205627441),
    ];

    expect(screens, hasLength(17));
    for (final item in screens) {
      final veto = HCVMLV3PhotoResidual.shouldVetoStrongV2(
        v2ScreenProbability: item.v2,
        v3CleanScreenProbability: item.clean,
        v3HardScreenProbability: item.hard,
        hardNegativeRealityProbability: item.hardNegativeReality,
      );
      expect(
        veto,
        isFalse,
        reason: 'hard-negative head must preserve SCREEN ${item.id}',
      );
    }

    expect(
      HCVMLV3PhotoResidual.shouldVetoStrongV2(
        v2ScreenProbability: 0.9996,
        v3CleanScreenProbability: 0.8519916534423828,
        v3HardScreenProbability: 0.8177489042282104,
        hardNegativeRealityProbability: 0.9974512457847595,
      ),
      isTrue,
      reason: 'HCV-172AC10B5D714EAB must be recovered as a PHOTO hard-negative',
    );

    expect(
      HCVMLV3PhotoResidual.hardNegativeRealityThreshold,
      closeTo(0.9837759923934937, 1e-12),
    );
  });

  test('legacy BMW false-positive veto remains active', () {
    expect(
      HCVMLV3PhotoResidual.shouldVetoStrongV2(
        v2ScreenProbability: 0.9396,
        v3CleanScreenProbability: 0.08312420547008514,
        v3HardScreenProbability: 0.12613323330879211,
        hardNegativeRealityProbability: 0.9999696016311646,
      ),
      isTrue,
    );
  });
}

class _Case {
  const _Case(
    this.id,
    this.v2,
    this.clean,
    this.hard,
    this.hardNegativeReality,
  );

  final String id;
  final double v2;
  final double clean;
  final double hard;
  final double hardNegativeReality;
}
