import 'package:flutter_test/flutter_test.dart';
import 'package:weather_forcast_app/src/core/weather_models.dart';

void main() {
  test('WeatherSnapshot serializes and deserializes', () {
    final snapshot = WeatherSnapshot(
      locationName: 'Lagos',
      region: 'Lagos',
      country: 'Nigeria',
      latitude: 6.52,
      longitude: 3.37,
      localTime: DateTime(2026, 4, 28, 12),
      current: const CurrentWeather(
        temperatureC: 29,
        feelsLikeC: 33,
        condition: 'Sunny',
        iconKey: 'sunny',
        humidity: 70,
        windKph: 12,
        uvIndex: 7,
        cloud: 10,
        precipitationMm: 0,
        isDay: true,
      ),
      hourly: [
        HourlyForecast(
          time: DateTime(2026, 4, 28, 13),
          temperatureC: 30,
          condition: 'Sunny',
          iconKey: 'sunny',
          chanceOfRain: 5,
        ),
      ],
      daily: [
        DailyForecast(
          date: DateTime(2026, 4, 29),
          minTempC: 24,
          maxTempC: 31,
          condition: 'Sunny',
          iconKey: 'sunny',
          chanceOfRain: 15,
        ),
      ],
      providerName: 'WeatherAPI',
      queryLabel: 'Lagos',
      fetchedAt: DateTime(2026, 4, 28, 12, 5),
    );

    final hydrated = WeatherSnapshot.fromJson(snapshot.toJson());

    expect(hydrated.locationName, 'Lagos');
    expect(hydrated.current.condition, 'Sunny');
    expect(hydrated.hourly.single.chanceOfRain, 5);
    expect(hydrated.daily.single.maxTempC, 31);
  });
}
