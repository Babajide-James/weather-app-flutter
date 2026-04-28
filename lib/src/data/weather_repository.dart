import '../core/weather_models.dart';
import 'weather_cache.dart';
import 'weather_exception.dart';
import 'weather_provider.dart';

class WeatherRepository {
  WeatherRepository({
    required List<WeatherProvider> providers,
    WeatherCache? cache,
  }) : _providers = providers
           .where((provider) => provider.isConfigured)
           .toList(),
       _cache = cache ?? const WeatherCache();

  final List<WeatherProvider> _providers;
  final WeatherCache _cache;

  Future<WeatherLoadResult> fetchByQuery(String query) async {
    return _execute(
      cacheKey: _cacheKey(query),
      action: (provider) => provider.fetchByQuery(query),
    );
  }

  Future<WeatherLoadResult> fetchByCoordinates(
    double latitude,
    double longitude,
  ) async {
    return _execute(
      cacheKey: _cacheKey(
        '${latitude.toStringAsFixed(3)},${longitude.toStringAsFixed(3)}',
      ),
      action: (provider) => provider.fetchByCoordinates(latitude, longitude),
    );
  }

  Future<WeatherLoadResult> _execute({
    required String cacheKey,
    required Future<WeatherSnapshot> Function(WeatherProvider provider) action,
  }) async {
    WeatherException? lastError;

    for (final provider in _providers) {
      try {
        final snapshot = await action(provider);
        await _cache.save(cacheKey, snapshot);
        return WeatherLoadResult(snapshot: snapshot);
      } on WeatherException catch (error) {
        lastError = error;
        if (error.type == WeatherErrorType.invalidQuery ||
            error.type == WeatherErrorType.network) {
          break;
        }
        if (!error.canTryFallback) {
          break;
        }
      }
    }

    final cached = await _cache.read(cacheKey);
    if (cached != null) {
      return WeatherLoadResult(
        snapshot: cached.copyWith(
          isStale: true,
          notice:
              'Showing the last saved forecast because fresh weather data is unavailable.',
        ),
        fromCache: true,
      );
    }

    throw lastError ??
        const WeatherException(
          WeatherErrorType.unknown,
          'Weather data could not be loaded right now.',
        );
  }

  String _cacheKey(String raw) {
    return raw.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9,.-]+'), '_');
  }
}
