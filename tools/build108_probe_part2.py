from pathlib import Path

def replace_once(text, old, new, label):
    if old not in text:
        raise SystemExit(f"missing anchor: {label}")
    return text.replace(old, new, 1)

probe_path = Path("lib/hcv_temporal_frequency_probe.dart")
probe = probe_path.read_text()
probe = replace_once(probe,
    '''      final latticeStrengths = lattice
          .map((m) => (m['latticeStrength'] as num?)?.toDouble())
          .whereType<double>()
          .toList()..sort();
      final spatialFamily = _compatibleModalBinCount(spatialBins);''',
    '''      final latticeStrengths = lattice
          .map((m) => (m['latticeStrength'] as num?)?.toDouble())
          .whereType<double>()
          .toList()..sort();
      final latticeSharpness = lattice
          .map((m) => (m['latticePeakSharpness'] as num?)?.toDouble())
          .whereType<double>()
          .toList()..sort();
      final latticeFamily = _compatibleLatticeSignatureCount(lattice);
      final spatialFamily = _compatibleModalBinCount(spatialBins);''',
    'lattice metrics')
probe = replace_once(probe,
    '''      final medianLattice = _medianStatic(latticeStrengths) ?? 0.0;
      return {''',
    '''      final medianLattice = _medianStatic(latticeStrengths) ?? 0.0;
      final medianLatticeSharpness = _medianStatic(latticeSharpness) ?? 0.0;
      return {''',
    'lattice sharpness median')
probe = replace_once(probe,
    '''        'medianSpatialLatticeStrength': medianLattice,
        'rollingShutterHighFrequencyCandidate':
            spatialFamily >= 8 && medianBand >= 0.45 && medianPhase >= 0.20,
        'spatialLatticeCandidate': latticeStrengths.length >= 6 && medianLattice >= 0.30,''',
    '''        'medianSpatialLatticeStrength': medianLattice,
        'medianSpatialLatticePeakSharpness': medianLatticeSharpness,
        'latticeFamilyCellCount': latticeFamily,
        'rollingShutterHighFrequencyCandidate':
            spatialFamily >= 8 && medianBand >= 0.45 && medianPhase >= 0.20,
        'harmonicRecoveryCorroborationCandidate':
            spatialFamily == 9 &&
            rowTimeFamily >= 8 &&
            medianBand >= 0.20 &&
            medianRt >= 0.20,
        'spatialLatticeCandidate': latticeStrengths.length >= 6 && medianLattice >= 0.30,
        'coherentSpatialLatticeCandidate':
            latticeFamily >= 8 &&
            medianLattice >= 0.30 &&
            medianLatticeSharpness >= 0.03,''',
    'stage candidate fields')
probe = replace_once(probe,
    '''    final rollingCandidates = stages.where((s) => s['rollingShutterHighFrequencyCandidate'] == true).length;
    final latticeCandidates = stages.where((s) => s['spatialLatticeCandidate'] == true).length;
    return {''',
    '''    final rollingCandidates = stages
        .where((s) => s['rollingShutterHighFrequencyCandidate'] == true)
        .length;
    final latticeCandidates = stages
        .where((s) => s['spatialLatticeCandidate'] == true)
        .length;
    final coherentLatticeCandidates = stages
        .where((s) => s['coherentSpatialLatticeCandidate'] == true)
        .length;
    final harmonicCorroborations = stages
        .where((s) => s['harmonicRecoveryCorroborationCandidate'] == true)
        .length;
    return {''',
    'advanced counts')
probe = replace_once(probe,
    '''      'spatialLatticeCandidateStageCount': latticeCandidates,
      'persistentHighFrequencyRollingShutterCandidate': rollingCandidates >= 2,
      'persistentSpatialLatticeCandidate': latticeCandidates >= 2,
      'advancedPhysicalDisplayCandidate': rollingCandidates >= 2 || latticeCandidates >= 2,
      'stages': stages,
      'note': 'Advanced V3.1 signatures are diagnostic only; physical iPhone validation is required before they can change production verdicts.',''',
    '''      'spatialLatticeCandidateStageCount': latticeCandidates,
      'coherentSpatialLatticeCandidateStageCount': coherentLatticeCandidates,
      'harmonicRecoveryCorroborationStageCount': harmonicCorroborations,
      'harmonicRecoveryExposureCorroborated': harmonicCorroborations >= 2,
      'persistentHighFrequencyRollingShutterCandidate': rollingCandidates >= 2,
      'persistentSpatialLatticeCandidate': latticeCandidates >= 2,
      'persistentCoherentSpatialLatticeCandidate': coherentLatticeCandidates >= 2,
      'advancedPhysicalDisplayCandidate':
          rollingCandidates >= 2 || coherentLatticeCandidates >= 2,
      'stages': stages,
      'note': 'V3.2 advanced signatures are diagnostic except the narrow harmonic display-family recovery, which additionally requires global HFR, row-time 9/9, harmonic-aware 9/9, and two independent short-exposure corroborations.',''',
    'advanced summary')
probe = replace_once(probe,
    '  static double? _medianStatic(List<double> sorted) {',
    '''  static Map<String, dynamic> _analyzeActiveIlluminationRealityV32(
    Map<String, dynamic> raw,
  ) {
    final challenge = raw['activeIlluminationChallenge'];
    if (challenge is! Map || challenge['analysisStatus'] != 'CAPTURED') {
      return {
        'analysisStatus': 'NOT_ANALYZED',
        'decisionRole': 'DIAGNOSTIC_ONLY_PENDING_PHYSICAL_VALIDATION',
        'positivePhysicalRealityEvidence': false,
        'reason': challenge is Map
            ? challenge['reason'] ?? 'ILLUMINATION_CHALLENGE_NOT_CAPTURED'
            : 'ILLUMINATION_CHALLENGE_MISSING',
      };
    }

    List<double> cellMeans(Object? snapshot) {
      if (snapshot is! Map) return const <double>[];
      final frames = snapshot['frames'];
      if (frames is! List) return const <double>[];
      final perCell = List.generate(9, (_) => <double>[]);
      for (final frame in frames) {
        if (frame is! List || frame.length != 9) continue;
        for (var cell = 0; cell < 9; cell++) {
          final profile = frame[cell];
          if (profile is! List) continue;
          final values = profile
              .whereType<num>()
              .map((n) => n.toDouble())
              .toList();
          if (values.isNotEmpty) {
            perCell[cell].add(values.reduce((a, b) => a + b) / values.length);
          }
        }
      }
      return perCell.map((values) {
        if (values.isEmpty) return 0.0;
        values.sort();
        return _medianStatic(values) ?? 0.0;
      }).toList(growable: false);
    }

    final off = cellMeans(challenge['torchOff']);
    final on = cellMeans(challenge['torchOn']);
    if (off.length != 9 || on.length != 9) {
      return {
        'analysisStatus': 'NOT_ANALYZED',
        'decisionRole': 'DIAGNOSTIC_ONLY_PENDING_PHYSICAL_VALIDATION',
        'positivePhysicalRealityEvidence': false,
        'reason': 'ILLUMINATION_CELL_RESPONSE_INCOMPLETE',
      };
    }
    final responses = <double>[];
    for (var i = 0; i < 9; i++) {
      responses.add((on[i] - off[i]) / max(0.03, off[i].abs()));
    }
    final sorted = List<double>.from(responses)..sort();
    final medianResponse = _medianStatic(sorted) ?? 0.0;
    final responsiveCells = responses.where((value) => value >= 0.08).length;
    final candidate = medianResponse >= 0.08 && responsiveCells >= 7;
    return {
      'analysisStatus': 'ANALYZED',
      'decisionRole': 'DIAGNOSTIC_ONLY_PENDING_PHYSICAL_VALIDATION',
      'positivePhysicalRealityEvidence': false,
      'activeIlluminationRealityCandidate': candidate,
      'medianRelativeLumaResponse': medianResponse,
      'responsiveCellCount': responsiveCells,
      'cellRelativeLumaResponses': responses,
      'torchLevel': challenge['torchLevel'],
      'note': 'Active illumination is candidate positive reality physics only; it cannot change production verdicts until physically validated.',
    };
  }

  static double? _medianStatic(List<double> sorted) {''',
    'active illumination analysis')
probe = replace_once(probe,
    "      'type': 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3_1',",
    "      'type': 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3_2',",
    'unavailable type')
probe = replace_once(probe,
    "          'DECISIONAL_VALIDATED_V3_DISPLAY_AND_MIXED_SCENE;V31_ADVANCED_PHYSICS_DIAGNOSTIC_ONLY',",
    "          'DECISIONAL_VALIDATED_V3_DISPLAY_AND_MIXED_SCENE;V32_HARMONIC_DISPLAY_RECOVERY_CANDIDATE;V32_REALITY_PHYSICS_DIAGNOSTIC_ONLY',",
    'unavailable role')
probe = replace_once(probe,
    '''    final maxLag = min(12, min(width, height) ~/ 3);
    var bestH = 0.0;
    var bestHLag = 0;
    var bestV = 0.0;
    var bestVLag = 0;
    for (var lag = 2; lag <= maxLag; lag++) {
      final h = correlation(lag, 0).abs();
      final v = correlation(0, lag).abs();
      if (h > bestH) { bestH = h; bestHLag = lag; }
      if (v > bestV) { bestV = v; bestVLag = lag; }
    }
    final latticeStrength = sqrt(bestH * bestV);
    return {''',
    '''    final maxLag = min(24, min(width, height) ~/ 3);
    final hByLag = <int, double>{};
    final vByLag = <int, double>{};
    var bestH = 0.0;
    var bestHLag = 0;
    var bestV = 0.0;
    var bestVLag = 0;
    for (var lag = 2; lag <= maxLag; lag++) {
      final h = correlation(lag, 0).abs();
      final v = correlation(0, lag).abs();
      hByLag[lag] = h;
      vByLag[lag] = v;
      if (h > bestH) { bestH = h; bestHLag = lag; }
      if (v > bestV) { bestV = v; bestVLag = lag; }
    }
    double secondBestOutsideNeighborhood(Map<int, double> values, int peakLag) {
      var second = 0.0;
      for (final entry in values.entries) {
        if ((entry.key - peakLag).abs() <= 1) continue;
        if (entry.value > second) second = entry.value;
      }
      return second;
    }
    final hSharpness = max(
      0.0,
      bestH - secondBestOutsideNeighborhood(hByLag, bestHLag),
    );
    final vSharpness = max(
      0.0,
      bestV - secondBestOutsideNeighborhood(vByLag, bestVLag),
    );
    final latticeStrength = sqrt(bestH * bestV);
    final latticePeakSharpness = sqrt(hSharpness * vSharpness);
    return {''',
    'lattice algorithm')
probe = replace_once(probe,
    '''      'verticalPeakLag': bestVLag,
      'gridWidth': width,''',
    '''      'verticalPeakLag': bestVLag,
      'horizontalPeakSharpness': hSharpness,
      'verticalPeakSharpness': vSharpness,
      'latticePeakSharpness': latticePeakSharpness,
      'gridWidth': width,''',
    'lattice output')
probe_path.write_text(probe)
