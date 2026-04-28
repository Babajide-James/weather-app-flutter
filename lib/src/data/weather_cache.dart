import 'package:shared_preferences/shared_preferences.dart';

import '../core/weather_models.dart';

class WeatherCache {
  const WeatherCache();

  static const _prefix = 'weather_cache_v1_';

  Future<void> save(String key, WeatherSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix$key', snapshot.toJson());
  }

  Future<WeatherSnapshot?> read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$key');
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return WeatherSnapshot.fromJson(raw);
  }
}
