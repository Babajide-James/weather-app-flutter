import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/api_keys.dart';
import '../core/weather_models.dart';
import 'weather_exception.dart';
import 'weather_provider.dart';

class OpenWeatherProvider implements WeatherProvider {
  OpenWeatherProvider({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  @override
  String get providerName => 'OpenWeather';

  @override
  bool get isConfigured => ApiKeys.openWeather.isNotEmpty;

  @override
  Future<WeatherSnapshot> fetchByCoordinates(
    double latitude,
    double longitude,
  ) async {
    final params = {
      'lat': '$latitude',
      'lon': '$longitude',
      'appid': ApiKeys.openWeather,
      'units': 'metric',
    };
    return _fetch(params);
  }

  @override
  Future<WeatherSnapshot> fetchByQuery(String query) async {
    final params = {
      'q': query,
      'appid': ApiKeys.openWeather,
      'units': 'metric',
    };
    return _fetch(params);
  }

  Future<WeatherSnapshot> _fetch(Map<String, String> params) async {
    final currentUri = Uri.https(
      'api.openweathermap.org',
      '/data/2.5/weather',
      params,
    );
    final forecastUri = Uri.https(
      'api.openweathermap.org',
      '/data/2.5/forecast',
      params,
    );

    try {
      final responses = await Future.wait([
        _client.get(currentUri),
        _client.get(forecastUri),
      ]);
      final currentResponse = responses[0];
      final forecastResponse = responses[1];
      final currentMap = _decode(currentResponse.body);
      final forecastMap = _decode(forecastResponse.body);

      if (currentResponse.statusCode >= 400 ||
          forecastResponse.statusCode >= 400) {
        final message =
            currentMap['message']?.toString() ??
            forecastMap['message']?.toString() ??
            'OpenWeather request failed.';
        throw _mapError(currentResponse.statusCode, message);
      }

      if ((currentMap['cod']?.toString() != '200') ||
          (forecastMap['cod']?.toString() != '200')) {
        final message =
            currentMap['message']?.toString() ??
            forecastMap['message']?.toString() ??
            'OpenWeather request failed.';
        throw _mapError(
          int.tryParse(currentMap['cod']?.toString() ?? '') ?? 500,
          message,
        );
      }

      final weather =
          (currentMap['weather'] as List<dynamic>).first
              as Map<String, dynamic>;
      final main = currentMap['main'] as Map<String, dynamic>;
      final wind = currentMap['wind'] as Map<String, dynamic>;
      final cloudMap = currentMap['clouds'] as Map<String, dynamic>? ?? {};
      final list = forecastMap['list'] as List<dynamic>;
      final city = forecastMap['city'] as Map<String, dynamic>;
      final timezoneSeconds = city['timezone'] as int? ?? 0;
      final offset = Duration(seconds: timezoneSeconds);
      final localNow = DateTime.now().toUtc().add(offset);

      final hourly = list
          .map((entry) => entry as Map<String, dynamic>)
          .where((entry) {
            final time = DateTime.parse(entry['dt_txt'] as String);
            return time.isAfter(localNow.subtract(const Duration(hours: 1)));
          })
          .take(8)
          .map((entry) {
            final weatherItem =
                (entry['weather'] as List<dynamic>).first
                    as Map<String, dynamic>;
            return HourlyForecast(
              time: DateTime.parse(entry['dt_txt'] as String),
              temperatureC:
                  ((entry['main'] as Map<String, dynamic>)['temp'] as num)
                      .toDouble(),
              condition: weatherItem['main'] as String,
              iconKey: weatherItem['description'].toString().toLowerCase(),
              chanceOfRain: (((entry['pop'] as num?)?.toDouble() ?? 0) * 100)
                  .round(),
            );
          })
          .toList();

      final grouped = <DateTime, List<Map<String, dynamic>>>{};
      for (final entry in list.cast<Map<String, dynamic>>()) {
        final time = DateTime.parse(entry['dt_txt'] as String);
        final dayKey = DateTime(time.year, time.month, time.day);
        grouped.putIfAbsent(dayKey, () => []).add(entry);
      }

      final daily = grouped.entries.take(5).map((entry) {
        final items = entry.value;
        final temperatures = items
            .map(
              (item) => ((item['main'] as Map<String, dynamic>)['temp'] as num)
                  .toDouble(),
            )
            .toList();
        final representative = items[items.length ~/ 2];
        final weatherItem =
            (representative['weather'] as List<dynamic>).first
                as Map<String, dynamic>;
        final rainChance = items
            .map(
              (item) =>
                  (((item['pop'] as num?)?.toDouble() ?? 0) * 100).round(),
            )
            .fold<int>(
              0,
              (highest, value) => value > highest ? value : highest,
            );
        return DailyForecast(
          date: entry.key,
          minTempC: temperatures.reduce((a, b) => a < b ? a : b),
          maxTempC: temperatures.reduce((a, b) => a > b ? a : b),
          condition: weatherItem['main'] as String,
          iconKey: weatherItem['description'].toString().toLowerCase(),
          chanceOfRain: rainChance,
        );
      }).toList();

      return WeatherSnapshot(
        locationName: currentMap['name'] as String,
        region: '',
        country: (city['country'] as String?) ?? '',
        latitude: (currentMap['coord']['lat'] as num).toDouble(),
        longitude: (currentMap['coord']['lon'] as num).toDouble(),
        localTime: localNow,
        providerName: providerName,
        queryLabel: params['q'] ?? '${params['lat']},${params['lon']}',
        fetchedAt: DateTime.now(),
        current: CurrentWeather(
          temperatureC: (main['temp'] as num).toDouble(),
          feelsLikeC: (main['feels_like'] as num).toDouble(),
          condition: weather['main'] as String,
          iconKey: weather['description'].toString().toLowerCase(),
          humidity: main['humidity'] as int,
          windKph: ((wind['speed'] as num?)?.toDouble() ?? 0) * 3.6,
          uvIndex: 0,
          cloud: cloudMap['all'] as int? ?? 0,
          precipitationMm: 0,
          isDay: (weather['icon'] as String? ?? '01d').endsWith('d'),
        ),
        hourly: hourly,
        daily: daily,
      );
    } on SocketException {
      throw const WeatherException(
        WeatherErrorType.network,
        'No internet connection. We could not reach OpenWeather.',
      );
    } on FormatException {
      throw const WeatherException(
        WeatherErrorType.api,
        'OpenWeather returned data in an unexpected format.',
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
    if (code == 401) {
      return WeatherException(
        WeatherErrorType.authentication,
        'OpenWeather key rejected the request.',
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
        'OpenWeather rate limit reached. Trying backup provider.',
        statusCode: code,
      );
    }
    return WeatherException(WeatherErrorType.api, message, statusCode: code);
  }
}
