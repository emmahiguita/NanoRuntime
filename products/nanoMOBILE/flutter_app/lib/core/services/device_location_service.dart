import 'package:geolocator/geolocator.dart';

final class DeviceLocationFix {
  const DeviceLocationFix({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.capturedAt,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime capturedAt;
}

/// Obtiene una sola posición foreground por una petición explícita del Chat.
/// No observa movimientos y no persiste coordenadas.
final class DeviceLocationService {
  DeviceLocationService._();

  static final instance = DeviceLocationService._();

  Future<DeviceLocationFix?> locateOnce() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      return DeviceLocationFix(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
        capturedAt: position.timestamp,
      );
    } on Object {
      // Incluye permiso revocado durante la llamada y GPS sin fix.
      return null;
    }
  }
}
