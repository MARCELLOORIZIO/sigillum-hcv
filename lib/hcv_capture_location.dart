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

class HCVCaptureLocationService {
  const HCVCaptureLocationService();

  Future<HCVCaptureLocation> getCurrentLocation() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw const HCVCaptureLocationException(
        'Attiva la localizzazione del telefono per stampare le coordinate.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const HCVCaptureLocationException(
        'Permesso posizione non concesso.',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw const HCVCaptureLocationException(
        'Permesso posizione bloccato. Abilitalo nelle impostazioni del telefono.',
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
  const HCVCaptureLocationException(this.message);

  final String message;

  @override
  String toString() => message;
}
