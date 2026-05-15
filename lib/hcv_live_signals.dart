import 'dart:async';
import 'dart:math';

import 'package:sensors_plus/sensors_plus.dart';

class HCVLiveSignals {
  final List<Map<String, dynamic>> _accelerometer = [];
  final List<Map<String, dynamic>> _gyroscope = [];

  StreamSubscription? _accSub;
  StreamSubscription? _gyroSub;

  DateTime? _startedAt;
  DateTime? _stoppedAt;

  Future<void> start() async {
    _accelerometer.clear();
    _gyroscope.clear();

    _startedAt = DateTime.now();
    _stoppedAt = null;

    _accSub = accelerometerEventStream().listen((event) {
      if (_accelerometer.length >= 300) return;

      _accelerometer.add({
        't': DateTime.now().toIso8601String(),
        'x': event.x,
        'y': event.y,
        'z': event.z,
      });
    });

    _gyroSub = gyroscopeEventStream().listen((event) {
      if (_gyroscope.length >= 300) return;

      _gyroscope.add({
        't': DateTime.now().toIso8601String(),
        'x': event.x,
        'y': event.y,
        'z': event.z,
      });
    });
  }

  Future<Map<String, dynamic>> stopAndBuildSummary() async {
    _stoppedAt = DateTime.now();

    await _accSub?.cancel();
    await _gyroSub?.cancel();

    _accSub = null;
    _gyroSub = null;

    return {
      'type': 'HCV_LIVE_SIGNALS_V1',
      'startedAt': _startedAt?.toIso8601String(),
      'stoppedAt': _stoppedAt?.toIso8601String(),
      'accelerometerSamples': _accelerometer.length,
      'gyroscopeSamples': _gyroscope.length,
      'accelerometerMotionScore': _motionScore(_accelerometer),
      'gyroscopeMotionScore': _motionScore(_gyroscope),
      'continuity': _continuityScore(),
      'signalsRecorded': _accelerometer.isNotEmpty || _gyroscope.isNotEmpty,
      'antiReplaySignal': 'PASSIVE_SENSOR_CAPTURE',
    };
  }

  double _motionScore(List<Map<String, dynamic>> samples) {
    if (samples.length < 2) return 0;

    double total = 0;

    for (int i = 1; i < samples.length; i++) {
      final a = samples[i - 1];
      final b = samples[i];

      final dx = ((b['x'] as num) - (a['x'] as num)).toDouble();
      final dy = ((b['y'] as num) - (a['y'] as num)).toDouble();
      final dz = ((b['z'] as num) - (a['z'] as num)).toDouble();

      total += sqrt(dx * dx + dy * dy + dz * dz);
    }

    return double.parse(total.toStringAsFixed(4));
  }

  String _continuityScore() {
    if (_startedAt == null || _stoppedAt == null) return 'UNKNOWN';

    final seconds = _stoppedAt!.difference(_startedAt!).inSeconds;

    if (seconds <= 0) return 'LOW';
    if (_accelerometer.length < 5 && _gyroscope.length < 5) return 'LOW';

    return 'RECORDED';
  }
}
