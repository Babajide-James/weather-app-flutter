import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/api_keys.dart';
import '../core/weather_models.dart';
import 'weather_exception.dart';
import 'weather_provider.dart';

class TomorrowWeatherProvider implements WeatherProvider {
  TomorrowWeatherProvider({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  @override
  String get providerName => 'Tomorrow.io';

  @override
  bool get isConfigured => ApiKeys.tomorrow.isNotEmpty;

  @override
  Future<WeatherSnapshot> fetchByCoordinates(
    double latitude,
    double longitude,
  ) {
    return _fetch('$latitude,$longitude');
  }

  @override
  Future<WeatherSnapshot> fetchByQuery(String query) {
    return _fetch(query);
  }

  Future<WeatherSnapshot> _fetch(String query) async {
    final realtimeUri = Uri.https('api.tomorrow.io', '/v4/weather/realtime', {
      'location': query,
      'apikey': ApiKeys.tomorrow,
      'units': 'metric',
    });
    final forecastUri = Uri.https('api.tomorrow.io', '/v4/weather/forecast', {
      'location': query,
      'apikey': ApiKeys.tomorrow,
      'units': 'metric',
    });

    try {
      final responses = await Future.wait([
        _client.get(realtimeUri),
        _client.get(forecastUri),
      ]);
      final realtimeResponse = responses[0];
      final forecastResponse = responses[1];
      final realtimeMap = _decode(realtimeResponse.body);
      final forecastMap = _decode(forecastResponse.body);

      if (realtimeResponse.statusCode >= 400 ||
          forecastResponse.statusCode >= 400) {
        final message =
            realtimeMap['message']?.toString() ??
            forecastMap['message']?.toString() ??
            'Tomorrow.io request failed.';
        throw _mapError(realtimeResponse.statusCode, message);
      }

      final data = realtimeMap['data'] as Map<String, dynamic>;
      final location = realtimeMap['location'] as Map<String, dynamic>;
      final timelines = forecastMap['timelines'] as Map<String, dynamic>;
      final hourlyTimeline = (timelines['hourly'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final dailyTimeline = (timelines['daily'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final currentValues = data['values'] as Map<String, dynamic>;
      final currentTime = DateTime.parse(data['time'] as String).toLocal();

      final hourly = hourlyTimeline.take(8).map((entry) {
        final values = entry['values'] as Map<String, dynamic>;
        final code = values['weatherCode'] as int? ?? 1001;
        return HourlyForecast(
          time: DateTime.parse(entry['time'] as String).toLocal(),
          temperatureC: (values['temperature'] as num?)?.toDouble() ?? 0,
          condition: _conditionFromTomorrowCode(code),
          iconKey: _conditionFromTomorrowCode(code).toLowerCase(),
          chanceOfRain:
              (values['precipitationProbability'] as num?)?.round() ?? 0,
        );
      }).toList();

      final daily = dailyTimeline.take(5).map((entry) {
        final values = entry['values'] as Map<String, dynamic>;
        final code =
            values['weatherCodeMax'] as int? ??
            values['weatherCodeMin'] as int? ??
            1001;
        return DailyForecast(
          date: DateTime.parse(entry['time'] as String).toLocal(),
          minTempC: (values['temperatureMin'] as num?)?.toDouble() ?? 0,
          maxTempC: (values['temperatureMax'] as num?)?.toDouble() ?? 0,
          condition: _conditionFromTomorrowCode(code),
          iconKey: _conditionFromTomorrowCode(code).toLowerCase(),
          chanceOfRain:
              (values['precipitationProbabilityAvg'] as num?)?.round() ?? 0,
        );
      }).toList();

      final currentCode = currentValues['weatherCode'] as int? ?? 1001;
      return WeatherSnapshot(
        locationName: location['name'] as String? ?? query,
        region: '',
        country: '',
        latitude: (location['lat'] as num?)?.toDouble() ?? 0,
        longitude: (location['lon'] as num?)?.toDouble() ?? 0,
        localTime: currentTime,
        providerName: providerName,
        queryLabel: query,
        fetchedAt: DateTime.now(),
        current: CurrentWeather(
          temperatureC: (currentValues['temperature'] as num?)?.toDouble() ?? 0,
          feelsLikeC:
              (currentValues['temperatureApparent'] as num?)?.toDouble() ?? 0,
          condition: _conditionFromTomorrowCode(currentCode),
          iconKey: _conditionFromTomorrowCode(currentCode).toLowerCase(),
          humidity: (currentValues['humidity'] as num?)?.round() ?? 0,
          windKph:
              ((currentValues['windSpeed'] as num?)?.toDouble() ?? 0) * 3.6,
          uvIndex: (currentValues['uvIndex'] as num?)?.toDouble() ?? 0,
          cloud: (currentValues['cloudCover'] as num?)?.round() ?? 0,
          precipitationMm:
              (currentValues['precipitationIntensity'] as num?)?.toDouble() ??
              0,
          isDay: ((currentValues['isDaytime'] as bool?) ?? true),
        ),
        hourly: hourly,
        daily: daily,
      );
    } on SocketException {
      throw const WeatherException(
        WeatherErrorType.network,
        'No internet connection. We could not reach Tomorrow.io.',
      );
    } on FormatException {
      throw const WeatherException(
        WeatherErrorType.api,
        'Tomorrow.io returned data in an unexpected format.',
      );
    }
  }

  Map<String, dynamic> _decode(String body) {
    if (body.isEmpty) {
      return <String, dynamic>{};
    }
    return jsonDecode(body) as Map<String, dynamic>;
  }

  WeatherException _mapError(int code, String message) {
    if (code == 401 || code == 403) {
      return WeatherException(
        WeatherErrorType.authentication,
        'Tomorrow.io key rejected the request.',
        statusCode: code,
      );
    }
    if (code == 404) {
      return WeatherException(
        WeatherErrorType.invalidQuery,
        message,
        statusCode: code,
      );
    }
    if (code == 429) {
      return WeatherException(
        WeatherErrorType.rateLimited,
        'Tomorrow.io rate limit reached.',
        statusCode: code,
      );
    }
    return WeatherException(WeatherErrorType.api, message, statusCode: code);
  }

  String _conditionFromTomorrowCode(int code) {
    switch (code) {
      case 1000:
        return 'Clear';
      case 1001:
        return 'Cloudy';
      case 1100:
      case 1101:
      case 1102:
        return 'Partly Cloudy';
      case 2000:
      case 2100:
        return 'Foggy';
      case 4000:
      case 4001:
      case 4200:
      case 4201:
        return 'Rain';
      case 5000:
      case 5001:
      case 5100:
      case 5101:
        return 'Snow';
      case 6000:
      case 6200:
      case 6201:
        return 'Freezing Rain';
      case 7000:
      case 7101:
      case 7102:
        return 'Ice';
      case 8000:
        return 'Thunderstorm';
      default:
        return 'Cloudy';
    }
  }
}
