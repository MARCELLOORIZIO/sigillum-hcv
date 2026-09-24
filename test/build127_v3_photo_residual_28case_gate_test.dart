import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_ml_v3_photo_residual.dart';

void main() {
  test('BUILD127 validated 28-case FP16 corpus vetoes only BMW reality', () {
    const cases = <_Case>[
    _Case('HCV-C65137D329B54D7F', false, 0.0010, 0.073847242, 0.127155513),
    _Case('HCV-88CC6F97F38A4D65', true, 0.9920, 0.953613281, 0.920078039),
    _Case('HCV-49FA17D6D28E4688', true, 0.9892, 0.962475896, 0.933414161),
    _Case('HCV-22ADB79B73BD4FBB', true, 0.9929, 0.910183966, 0.867636323),
    _Case('HCV-3DC36F32EAEA4979', false, 0.0512, 0.089320891, 0.139772236),
    _Case('HCV-93FC9CC6AE7B4A1E', false, 0.1286, 0.238149375, 0.304883122),
    _Case('HCV-66B58B42B999416A', true, 0.9993, 0.960200727, 0.930551946),
    _Case('HCV-27463957577E4ED5', true, 0.9716, 0.985965192, 0.966782570),
    _Case('HCV-4B92D5AC4CAD4C31', false, 0.0102, 0.059683852, 0.108928725),
    _Case('HCV-D0DFF784C2D446DF', true, 0.9377, 0.967316747, 0.935002327),
    _Case('HCV-AE0F458640004FE7', true, 0.9972, 0.973800361, 0.953398049),
    _Case('HCV-6A5B55785D2C4D9E', true, 0.9633, 0.236175060, 0.296962857),
    _Case('HCV-C6FA3CBBD5714382', true, 0.9979, 0.972454786, 0.947705090),
    _Case('HCV-DB4F2901C5E04D24', false, 0.0061, 0.360647887, 0.396612763),
    _Case('HCV-6AE8CBFD1D404588', false, 0.0118, 0.883248925, 0.847530305),
    _Case('HCV-581449500C1846FC', false, 0.9396, 0.083124205, 0.126133233),
    _Case('HCV-D516E077C10140D9', true, 0.9633, 0.978363037, 0.957448483),
    _Case('HCV-C6C696A6E63344DF', true, 0.9937, 0.811744273, 0.749025226),
    _Case('HCV-46972974351E4DB9', false, 0.4092, 0.034067154, 0.071090229),
    _Case('HCV-2C077C76217747B6', false, 0.7993, 0.056732561, 0.096965507),
    _Case('HCV-E9F75F00F6134AF7', true, 0.9754, 0.304911762, 0.311984092),
    _Case('HCV-C8C399E3E9BE4B86', true, 0.9845, 0.897673249, 0.822535157),
    _Case('HCV-BF1B0754CA594555', true, 0.8943, 0.972742379, 0.962737739),
    _Case('HCV-AEAFD4855C0B416E', true, 0.4038, 0.525791526, 0.603410184),
    _Case('HCV-DE79FC815C55453F', false, 0.3839, 0.321000606, 0.345489353),
    _Case('HCV-E7F4F3D3456A4AE1', true, 0.3723, 0.990484715, 0.986592412),
    _Case('HCV-BD06C9FD69284BB6', true, 0.9265, 0.241004199, 0.266232550),
    _Case('HCV-C2ACF74657CD43F1', false, 0.1475, 0.067693435, 0.116312169),
    ];

    final vetoed = <String>[];
    for (final item in cases) {
      final veto = HCVMLV3PhotoResidual.shouldVetoStrongV2(
        v2ScreenProbability: item.v2,
        v3CleanScreenProbability: item.clean,
        v3HardScreenProbability: item.hard,
      );
      if (veto) vetoed.add(item.id);
      if (item.screenGroundTruth) {
        expect(
          veto,
          isFalse,
          reason: 'V3 residual must not veto validated SCREEN case ${item.id}',
        );
      }
    }

    expect(cases.where((item) => item.screenGroundTruth), hasLength(17));
    expect(cases.where((item) => !item.screenGroundTruth), hasLength(11));
    expect(vetoed, const <String>['HCV-581449500C1846FC']);
  });
}

class _Case {
  const _Case(this.id, this.screenGroundTruth, this.v2, this.clean, this.hard);

  final String id;
  final bool screenGroundTruth;
  final double v2;
  final double clean;
  final double hard;
}
