import '../core/weather_models.dart';

abstract class WeatherProvider {
  String get providerName;
  bool get isConfigured;

  Future<WeatherSnapshot> fetchByQuery(String query);
  Future<WeatherSnapshot> fetchByCoordinates(double latitude, double longitude);
}
