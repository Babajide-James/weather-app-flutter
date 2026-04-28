import 'package:flutter/foundation.dart';

import '../core/weather_models.dart';
import '../data/weather_exception.dart';
import '../data/weather_repository.dart';
import '../services/location_service.dart';

enum WeatherViewState { idle, loading, loaded, error }

class WeatherController extends ChangeNotifier {
  WeatherController({
    required WeatherRepository repository,
    required LocationService locationService,
  }) : _repository = repository,
       _locationService = locationService;

  final WeatherRepository _repository;
  final LocationService _locationService;

  WeatherViewState state = WeatherViewState.idle;
  WeatherSnapshot? snapshot;
  WeatherException? error;
  bool isRefreshing = false;
  bool detailsExpanded = false;
  bool showingDeviceLocation = true;
  String? activeCityQuery;
  double? _lastLatitude;
  double? _lastLongitude;

  Future<void> loadInitial() async {
    if (state != WeatherViewState.idle) {
      return;
    }
    await loadCurrentLocation();
  }

  Future<void> loadCurrentLocation({bool refresh = false}) async {
    if (refresh && snapshot != null) {
      isRefreshing = true;
    } else {
      state = WeatherViewState.loading;
    }
    error = null;
    notifyListeners();

    try {
      final position = await _locationService.getCurrentPosition();
      _lastLatitude = position.latitude;
      _lastLongitude = position.longitude;
      showingDeviceLocation = true;
      activeCityQuery = null;
      final result = await _repository.fetchByCoordinates(
        position.latitude,
        position.longitude,
      );
      snapshot = result.snapshot;
      state = WeatherViewState.loaded;
    } on WeatherException catch (exception) {
      error = exception;
      state = WeatherViewState.error;
    } finally {
      isRefreshing = false;
      notifyListeners();
    }
  }

  Future<void> searchCity(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      error = const WeatherException(
        WeatherErrorType.invalidQuery,
        'Enter a city name to search for weather.',
      );
      state = WeatherViewState.error;
      notifyListeners();
      return;
    }

    if (snapshot != null) {
      isRefreshing = true;
    } else {
      state = WeatherViewState.loading;
    }
    error = null;
    notifyListeners();

    try {
      showingDeviceLocation = false;
      activeCityQuery = trimmed;
      final result = await _repository.fetchByQuery(trimmed);
      snapshot = result.snapshot;
      state = WeatherViewState.loaded;
    } on WeatherException catch (exception) {
      error = exception;
      state = WeatherViewState.error;
    } finally {
      isRefreshing = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    if (showingDeviceLocation) {
      await loadCurrentLocation(refresh: true);
      return;
    }
    final query = activeCityQuery;
    if (query != null) {
      await searchCity(query);
      return;
    }
    if (_lastLatitude != null && _lastLongitude != null) {
      await loadCurrentLocation(refresh: true);
    }
  }

  Future<void> retry() async {
    if (showingDeviceLocation) {
      await loadCurrentLocation();
      return;
    }
    final query = activeCityQuery;
    if (query != null) {
      await searchCity(query);
    }
  }

  Future<void> openAppSettings() => _locationService.openSettings();

  Future<void> openLocationSettings() =>
      _locationService.openLocationSettings();

  void toggleDetails() {
    detailsExpanded = !detailsExpanded;
    notifyListeners();
  }
}
