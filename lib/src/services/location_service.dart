import 'package:geolocator/geolocator.dart';

import '../data/weather_exception.dart';

class LocationService {
  Future<Position> getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const WeatherException(
        WeatherErrorType.locationDisabled,
        'Location services are turned off on this device.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const WeatherException(
        WeatherErrorType.permissionDenied,
        'Location permission was denied. Search for a city or allow location access.',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      throw const WeatherException(
        WeatherErrorType.permissionDeniedForever,
        'Location permission is permanently denied. Open settings to enable it again.',
      );
    }

    return Geolocator.getCurrentPosition();
  }

  Future<void> openSettings() => Geolocator.openAppSettings();

  Future<void> openLocationSettings() => Geolocator.openLocationSettings();
}
