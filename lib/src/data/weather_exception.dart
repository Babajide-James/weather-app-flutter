enum WeatherErrorType {
  network,
  locationDisabled,
  permissionDenied,
  permissionDeniedForever,
  invalidQuery,
  rateLimited,
  authentication,
  api,
  unknown,
}

class WeatherException implements Exception {
  const WeatherException(this.type, this.message, {this.statusCode});

  final WeatherErrorType type;
  final String message;
  final int? statusCode;

  bool get canTryFallback =>
      type == WeatherErrorType.rateLimited ||
      type == WeatherErrorType.authentication ||
      type == WeatherErrorType.api;
}
