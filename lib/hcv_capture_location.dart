import 'package:geolocator/geolocator.dart';

class HCVCaptureLocation {
  const HCVCaptureLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.measuredAt,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime measuredAt;

  String get watermarkText {
    final accuracy = accuracyMeters.isFinite
        ? ' ±${accuracyMeters.round()}m'
        : '';
    return 'GPS ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}$accuracy';
  }

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'accuracyMeters': accuracyMeters,
    'measuredAt': measuredAt.toUtc().toIso8601String(),
    'source': 'DEVICE_LOCATION_WHEN_IN_USE',
  };
}

enum HCVCaptureLocationFailure {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  unavailable,
}

class HCVCaptureLocationService {
  const HCVCaptureLocationService();

  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  Future<HCVCaptureLocation> getCurrentLocation() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw const HCVCaptureLocationException(
        HCVCaptureLocationFailure.serviceDisabled,
        'LOCATION_SERVICE_DISABLED',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      throw const HCVCaptureLocationException(
        HCVCaptureLocationFailure.permissionDeniedForever,
        'LOCATION_PERMISSION_DENIED_FOREVER',
      );
    }
    if (permission == LocationPermission.denied) {
      throw const HCVCaptureLocationException(
        HCVCaptureLocationFailure.permissionDenied,
        'LOCATION_PERMISSION_DENIED',
      );
    }
    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      throw const HCVCaptureLocationException(
        HCVCaptureLocationFailure.unavailable,
        'LOCATION_PERMISSION_UNAVAILABLE',
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 12),
      ),
    );

    return HCVCaptureLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
      measuredAt: position.timestamp,
    );
  }
}

class HCVCaptureLocationException implements Exception {
  const HCVCaptureLocationException(this.reason, this.message);

  final HCVCaptureLocationFailure reason;
  final String message;

  @override
  String toString() => message;
}
