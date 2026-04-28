import 'dart:convert';

class WeatherSnapshot {
  const WeatherSnapshot({
    required this.locationName,
    required this.region,
    required this.country,
    required this.latitude,
    required this.longitude,
    required this.localTime,
    required this.current,
    required this.hourly,
    required this.daily,
    required this.providerName,
    required this.queryLabel,
    required this.fetchedAt,
    this.isStale = false,
    this.notice,
  });

  final String locationName;
  final String region;
  final String country;
  final double latitude;
  final double longitude;
  final DateTime localTime;
  final CurrentWeather current;
  final List<HourlyForecast> hourly;
  final List<DailyForecast> daily;
  final String providerName;
  final String queryLabel;
  final DateTime fetchedAt;
  final bool isStale;
  final String? notice;

  WeatherSnapshot copyWith({
    String? locationName,
    String? region,
    String? country,
    double? latitude,
    double? longitude,
    DateTime? localTime,
    CurrentWeather? current,
    List<HourlyForecast>? hourly,
    List<DailyForecast>? daily,
    String? providerName,
    String? queryLabel,
    DateTime? fetchedAt,
    bool? isStale,
    String? notice,
  }) {
    return WeatherSnapshot(
      locationName: locationName ?? this.locationName,
      region: region ?? this.region,
      country: country ?? this.country,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      localTime: localTime ?? this.localTime,
      current: current ?? this.current,
      hourly: hourly ?? this.hourly,
      daily: daily ?? this.daily,
      providerName: providerName ?? this.providerName,
      queryLabel: queryLabel ?? this.queryLabel,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      isStale: isStale ?? this.isStale,
      notice: notice ?? this.notice,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'locationName': locationName,
      'region': region,
      'country': country,
      'latitude': latitude,
      'longitude': longitude,
      'localTime': localTime.toIso8601String(),
      'current': current.toMap(),
      'hourly': hourly.map((item) => item.toMap()).toList(),
      'daily': daily.map((item) => item.toMap()).toList(),
      'providerName': providerName,
      'queryLabel': queryLabel,
      'fetchedAt': fetchedAt.toIso8601String(),
      'isStale': isStale,
      'notice': notice,
    };
  }

  String toJson() => jsonEncode(toMap());

  factory WeatherSnapshot.fromJson(String source) {
    final map = jsonDecode(source) as Map<String, dynamic>;
    return WeatherSnapshot(
      locationName: map['locationName'] as String,
      region: map['region'] as String? ?? '',
      country: map['country'] as String? ?? '',
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      localTime: DateTime.parse(map['localTime'] as String),
      current: CurrentWeather.fromMap(map['current'] as Map<String, dynamic>),
      hourly: (map['hourly'] as List<dynamic>)
          .map((item) => HourlyForecast.fromMap(item as Map<String, dynamic>))
          .toList(),
      daily: (map['daily'] as List<dynamic>)
          .map((item) => DailyForecast.fromMap(item as Map<String, dynamic>))
          .toList(),
      providerName: map['providerName'] as String,
      queryLabel: map['queryLabel'] as String,
      fetchedAt: DateTime.parse(map['fetchedAt'] as String),
      isStale: map['isStale'] as bool? ?? false,
      notice: map['notice'] as String?,
    );
  }
}

class CurrentWeather {
  const CurrentWeather({
    required this.temperatureC,
    required this.feelsLikeC,
    required this.condition,
    required this.iconKey,
    required this.humidity,
    required this.windKph,
    required this.uvIndex,
    required this.cloud,
    required this.precipitationMm,
    required this.isDay,
  });

  final double temperatureC;
  final double feelsLikeC;
  final String condition;
  final String iconKey;
  final int humidity;
  final double windKph;
  final double uvIndex;
  final int cloud;
  final double precipitationMm;
  final bool isDay;

  Map<String, dynamic> toMap() {
    return {
      'temperatureC': temperatureC,
      'feelsLikeC': feelsLikeC,
      'condition': condition,
      'iconKey': iconKey,
      'humidity': humidity,
      'windKph': windKph,
      'uvIndex': uvIndex,
      'cloud': cloud,
      'precipitationMm': precipitationMm,
      'isDay': isDay,
    };
  }

  factory CurrentWeather.fromMap(Map<String, dynamic> map) {
    return CurrentWeather(
      temperatureC: (map['temperatureC'] as num).toDouble(),
      feelsLikeC: (map['feelsLikeC'] as num).toDouble(),
      condition: map['condition'] as String,
      iconKey: map['iconKey'] as String,
      humidity: map['humidity'] as int,
      windKph: (map['windKph'] as num).toDouble(),
      uvIndex: (map['uvIndex'] as num).toDouble(),
      cloud: map['cloud'] as int,
      precipitationMm: (map['precipitationMm'] as num).toDouble(),
      isDay: map['isDay'] as bool,
    );
  }
}

class HourlyForecast {
  const HourlyForecast({
    required this.time,
    required this.temperatureC,
    required this.condition,
    required this.iconKey,
    required this.chanceOfRain,
  });

  final DateTime time;
  final double temperatureC;
  final String condition;
  final String iconKey;
  final int chanceOfRain;

  Map<String, dynamic> toMap() {
    return {
      'time': time.toIso8601String(),
      'temperatureC': temperatureC,
      'condition': condition,
      'iconKey': iconKey,
      'chanceOfRain': chanceOfRain,
    };
  }

  factory HourlyForecast.fromMap(Map<String, dynamic> map) {
    return HourlyForecast(
      time: DateTime.parse(map['time'] as String),
      temperatureC: (map['temperatureC'] as num).toDouble(),
      condition: map['condition'] as String,
      iconKey: map['iconKey'] as String,
      chanceOfRain: map['chanceOfRain'] as int,
    );
  }
}

class DailyForecast {
  const DailyForecast({
    required this.date,
    required this.minTempC,
    required this.maxTempC,
    required this.condition,
    required this.iconKey,
    required this.chanceOfRain,
  });

  final DateTime date;
  final double minTempC;
  final double maxTempC;
  final String condition;
  final String iconKey;
  final int chanceOfRain;

  Map<String, dynamic> toMap() {
    return {
      'date': date.toIso8601String(),
      'minTempC': minTempC,
      'maxTempC': maxTempC,
      'condition': condition,
      'iconKey': iconKey,
      'chanceOfRain': chanceOfRain,
    };
  }

  factory DailyForecast.fromMap(Map<String, dynamic> map) {
    return DailyForecast(
      date: DateTime.parse(map['date'] as String),
      minTempC: (map['minTempC'] as num).toDouble(),
      maxTempC: (map['maxTempC'] as num).toDouble(),
      condition: map['condition'] as String,
      iconKey: map['iconKey'] as String,
      chanceOfRain: map['chanceOfRain'] as int,
    );
  }
}

class WeatherLoadResult {
  const WeatherLoadResult({required this.snapshot, this.fromCache = false});

  final WeatherSnapshot snapshot;
  final bool fromCache;
}
