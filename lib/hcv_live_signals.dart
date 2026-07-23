import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:sensors_plus/sensors_plus.dart';

class HCVLiveSignals with WidgetsBindingObserver {
  final List<Map<String, dynamic>> _accelerometer = [];
  final List<Map<String, dynamic>> _gyroscope = [];

  StreamSubscription? _accSub;
  StreamSubscription? _gyroSub;
  Timer? _safetyTimer;

  DateTime? _startedAt;
  DateTime? _stoppedAt;
  bool _observingLifecycle = false;

  bool get isRecording => _accSub != null || _gyroSub != null;

  Future<void> start({
    Duration maximumDuration = const Duration(minutes: 30),
  }) async {
    await cancel();
    _accelerometer.clear();
    _gyroscope.clear();

    _startedAt = DateTime.now();
    _stoppedAt = null;

    if (!_observingLifecycle) {
      WidgetsBinding.instance.addObserver(this);
      _observingLifecycle = true;
    }

    _accSub = accelerometerEventStream().listen(
      (event) {
        if (_accelerometer.length >= 300) return;
        _accelerometer.add({
          't': DateTime.now().toIso8601String(),
          'x': event.x,
          'y': event.y,
          'z': event.z,
        });
      },
      onError: (_) {},
      cancelOnError: false,
    );

    _gyroSub = gyroscopeEventStream().listen(
      (event) {
        if (_gyroscope.length >= 300) return;
        _gyroscope.add({
          't': DateTime.now().toIso8601String(),
          'x': event.x,
          'y': event.y,
          'z': event.z,
        });
      },
      onError: (_) {},
      cancelOnError: false,
    );

    _safetyTimer = Timer(maximumDuration, () {
      unawaited(cancel());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      unawaited(cancel());
    }
  }

  Future<Map<String, dynamic>> stopAndBuildSummary() async {
    _stoppedAt = DateTime.now();
    await _cancelSubscriptions();

    return {
      'type': 'HCV_LIVE_SIGNALS_V1',
      'startedAt': _startedAt?.toIso8601String(),
      'stoppedAt': _stoppedAt?.toIso8601String(),
      'durationSeconds': _durationSeconds(),
      'accelerometerSamples': _accelerometer.length,
      'gyroscopeSamples': _gyroscope.length,
      'accelerometerMotionScore': _motionScore(_accelerometer),
      'gyroscopeMotionScore': _motionScore(_gyroscope),
      'continuity': _continuityScore(),
      'signalsRecorded': _accelerometer.isNotEmpty || _gyroscope.isNotEmpty,
      'antiReplaySignal': 'PASSIVE_SENSOR_CAPTURE',
      'challengeType': 'NONE_PASSIVE',
    };
  }

  Future<void> cancel() async {
    if (_startedAt != null && _stoppedAt == null) {
      _stoppedAt = DateTime.now();
    }
    await _cancelSubscriptions();
  }

  Future<void> dispose() async {
    await cancel();
    if (_observingLifecycle) {
      WidgetsBinding.instance.removeObserver(this);
      _observingLifecycle = false;
    }
  }

  Future<void> _cancelSubscriptions() async {
    _safetyTimer?.cancel();
    _safetyTimer = null;

    final acc = _accSub;
    final gyro = _gyroSub;
    _accSub = null;
    _gyroSub = null;

    try {
      await acc?.cancel();
    } catch (_) {}
    try {
      await gyro?.cancel();
    } catch (_) {}
  }

  int _durationSeconds() {
    if (_startedAt == null || _stoppedAt == null) return 0;
    return _stoppedAt!.difference(_startedAt!).inSeconds;
  }

  double _motionScore(List<Map<String, dynamic>> samples) {
    if (samples.length < 2) return 0;

    double total = 0;
    for (var index = 1; index < samples.length; index++) {
      final first = samples[index - 1];
      final second = samples[index];
      final dx = ((second['x'] as num) - (first['x'] as num)).toDouble();
      final dy = ((second['y'] as num) - (first['y'] as num)).toDouble();
      final dz = ((second['z'] as num) - (first['z'] as num)).toDouble();
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
