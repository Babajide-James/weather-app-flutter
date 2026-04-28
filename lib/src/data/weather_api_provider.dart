import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/api_keys.dart';
import '../core/weather_models.dart';
import 'weather_exception.dart';
import 'weather_provider.dart';

class WeatherApiProvider implements WeatherProvider {
  WeatherApiProvider({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  String get providerName => 'WeatherAPI';

  @override
  bool get isConfigured => ApiKeys.weatherApi.isNotEmpty;

  @override
  Future<WeatherSnapshot> fetchByCoordinates(
    double latitude,
    double longitude,
  ) {
    return _fetchWeather('$latitude,$longitude');
  }

  @override
  Future<WeatherSnapshot> fetchByQuery(String query) {
    return _fetchWeather(query);
  }

  Future<WeatherSnapshot> _fetchWeather(String query) async {
    final uri = Uri.https('api.weatherapi.com', '/v1/forecast.json', {
      'key': ApiKeys.weatherApi,
      'q': query,
      'days': '5',
      'aqi': 'no',
      'alerts': 'no',
    });

    try {
      final response = await _client.get(uri);
      final map = _decode(response.body);

      if (response.statusCode >= 400 || map['error'] != null) {
        throw _mapError(
          message: map['error']?['message'] as String? ?? 'WeatherAPI failed.',
          code: map['error']?['code'] as int? ?? response.statusCode,
        );
      }

      final location = map['location'] as Map<String, dynamic>;
      final current = map['current'] as Map<String, dynamic>;
      final forecastDays =
          (map['forecast'] as Map<String, dynamic>)['forecastday']
              as List<dynamic>;

      final localTime = DateTime.parse(location['localtime'] as String);
      final hourly = <HourlyForecast>[];
      for (final day in forecastDays) {
        for (final hour
            in (day as Map<String, dynamic>)['hour'] as List<dynamic>) {
          final hourMap = hour as Map<String, dynamic>;
          final time = DateTime.parse(hourMap['time'] as String);
          if (time.isAfter(localTime.subtract(const Duration(hours: 1))) &&
              hourly.length < 8) {
            hourly.add(
              HourlyForecast(
                time: time,
                temperatureC: (hourMap['temp_c'] as num).toDouble(),
                condition:
                    (hourMap['condition'] as Map<String, dynamic>)['text']
                        as String,
                iconKey: (hourMap['condition'] as Map<String, dynamic>)['text']
                    .toString()
                    .toLowerCase(),
                chanceOfRain: hourMap['chance_of_rain'] as int? ?? 0,
              ),
            );
          }
        }
      }

      final daily = forecastDays.take(5).map((day) {
        final dayMap = day as Map<String, dynamic>;
        final values = dayMap['day'] as Map<String, dynamic>;
        return DailyForecast(
          date: DateTime.parse(dayMap['date'] as String),
          minTempC: (values['mintemp_c'] as num).toDouble(),
          maxTempC: (values['maxtemp_c'] as num).toDouble(),
          condition:
              (values['condition'] as Map<String, dynamic>)['text'] as String,
          iconKey: (values['condition'] as Map<String, dynamic>)['text']
              .toString()
              .toLowerCase(),
          chanceOfRain: values['daily_chance_of_rain'] as int? ?? 0,
        );
      }).toList();

      return WeatherSnapshot(
        locationName: location['name'] as String,
        region: location['region'] as String? ?? '',
        country: location['country'] as String? ?? '',
        latitude: (location['lat'] as num).toDouble(),
        longitude: (location['lon'] as num).toDouble(),
        localTime: localTime,
        providerName: providerName,
        queryLabel: query,
        fetchedAt: DateTime.now(),
        current: CurrentWeather(
          temperatureC: (current['temp_c'] as num).toDouble(),
          feelsLikeC: (current['feelslike_c'] as num).toDouble(),
          condition:
              (current['condition'] as Map<String, dynamic>)['text'] as String,
          iconKey: (current['condition'] as Map<String, dynamic>)['text']
              .toString()
              .toLowerCase(),
          humidity: current['humidity'] as int,
          windKph: (current['wind_kph'] as num).toDouble(),
          uvIndex: (current['uv'] as num?)?.toDouble() ?? 0,
          cloud: current['cloud'] as int? ?? 0,
          precipitationMm: (current['precip_mm'] as num?)?.toDouble() ?? 0,
          isDay: (current['is_day'] as int? ?? 1) == 1,
        ),
        hourly: hourly,
        daily: daily,
      );
    } on SocketException {
      throw const WeatherException(
        WeatherErrorType.network,
        'No internet connection. We could not reach WeatherAPI.',
      );
    } on FormatException {
      throw const WeatherException(
        WeatherErrorType.api,
        'WeatherAPI returned data in an unexpected format.',
      );
    }
  }

  Map<String, dynamic> _decode(String body) {
    if (body.isEmpty) {
      return <String, dynamic>{};
    }
    return jsonDecode(body) as Map<String, dynamic>;
  }

  WeatherException _mapError({required String message, required int code}) {
    if (code == 1006) {
      return WeatherException(
        WeatherErrorType.invalidQuery,
        message,
        statusCode: code,
      );
    }
    if (code == 2006 || code == 2007 || code == 2008) {
      return WeatherException(
        WeatherErrorType.authentication,
        'WeatherAPI key rejected the request.',
        statusCode: code,
      );
    }
    if (code == 2009 || code == 429) {
      return WeatherException(
        WeatherErrorType.rateLimited,
        'WeatherAPI rate limit reached. Trying backup provider.',
        statusCode: code,
      );
    }
    return WeatherException(WeatherErrorType.api, message, statusCode: code);
  }
}
