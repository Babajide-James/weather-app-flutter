import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/weather_models.dart';
import '../data/weather_exception.dart';
import 'weather_controller.dart';

class WeatherHomePage extends StatefulWidget {
  const WeatherHomePage({super.key, required this.controller});

  final WeatherController controller;

  @override
  State<WeatherHomePage> createState() => _WeatherHomePageState();
}

class _WeatherHomePageState extends State<WeatherHomePage> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    unawaited(widget.controller.loadInitial());
  }

  @override
  void dispose() {
    _searchController.dispose();
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final snapshot = widget.controller.snapshot;
        return Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: _buildBackgroundGradient(snapshot),
            ),
            child: SafeArea(
              child: Stack(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 450),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: _buildBody(context),
                  ),
                  if (widget.controller.isRefreshing)
                    const Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      child: LinearProgressIndicator(minHeight: 3),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (widget.controller.state) {
      case WeatherViewState.idle:
      case WeatherViewState.loading:
        return _LoadingView(
          key: const ValueKey('loading'),
          searchController: _searchController,
          onSearch: _handleSearch,
        );
      case WeatherViewState.error:
        return _ErrorView(
          key: const ValueKey('error'),
          searchController: _searchController,
          error: widget.controller.error,
          onRetry: widget.controller.retry,
          onSearch: _handleSearch,
          onCurrentLocation: widget.controller.loadCurrentLocation,
          onOpenSettings: widget.controller.openAppSettings,
          onOpenLocationSettings: widget.controller.openLocationSettings,
        );
      case WeatherViewState.loaded:
        final snapshot = widget.controller.snapshot!;
        return _WeatherContentView(
          key: const ValueKey('content'),
          snapshot: snapshot,
          searchController: _searchController,
          detailsExpanded: widget.controller.detailsExpanded,
          onSearch: _handleSearch,
          onRefresh: widget.controller.refresh,
          onUseLocation: widget.controller.loadCurrentLocation,
          onToggleDetails: widget.controller.toggleDetails,
        );
    }
  }

  Future<void> _handleSearch() async {
    FocusScope.of(context).unfocus();
    await widget.controller.searchCity(_searchController.text);
  }

  LinearGradient _buildBackgroundGradient(WeatherSnapshot? snapshot) {
    final condition = snapshot?.current.condition.toLowerCase() ?? '';
    if (condition.contains('rain') || condition.contains('storm')) {
      return const LinearGradient(
        colors: [Color(0xFF091E3D), Color(0xFF1F4287), Color(0xFF278EA5)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    if (condition.contains('cloud') || condition.contains('fog')) {
      return const LinearGradient(
        colors: [Color(0xFF16222A), Color(0xFF3A6073), Color(0xFF90AFC5)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    return const LinearGradient(
      colors: [Color(0xFF071B34), Color(0xFF0D4C92), Color(0xFF87CEEB)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView({
    super.key,
    required this.searchController,
    required this.onSearch,
  });

  final TextEditingController searchController;
  final Future<void> Function() onSearch;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        _Header(searchController: searchController, onSearch: onSearch),
        const SizedBox(height: 24),
        const _PulseSkeleton(height: 220),
        const SizedBox(height: 18),
        const _PulseSkeleton(height: 140),
        const SizedBox(height: 18),
        const _PulseSkeleton(height: 280),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    super.key,
    required this.searchController,
    required this.error,
    required this.onRetry,
    required this.onSearch,
    required this.onCurrentLocation,
    required this.onOpenSettings,
    required this.onOpenLocationSettings,
  });

  final TextEditingController searchController;
  final WeatherException? error;
  final Future<void> Function() onRetry;
  final Future<void> Function() onSearch;
  final Future<void> Function({bool refresh}) onCurrentLocation;
  final Future<void> Function() onOpenSettings;
  final Future<void> Function() onOpenLocationSettings;

  @override
  Widget build(BuildContext context) {
    final message = _friendlyMessage(error);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        _Header(searchController: searchController, onSearch: onSearch),
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 56,
                color: Colors.white,
              ),
              const SizedBox(height: 16),
              Text(
                message.$1,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message.$2,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.84),
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => onCurrentLocation(refresh: false),
                    icon: const Icon(Icons.my_location_rounded),
                    label: const Text('Use My Location'),
                  ),
                  if (error?.type == WeatherErrorType.permissionDeniedForever)
                    OutlinedButton.icon(
                      onPressed: onOpenSettings,
                      icon: const Icon(Icons.settings_outlined),
                      label: const Text('Open App Settings'),
                    ),
                  if (error?.type == WeatherErrorType.locationDisabled)
                    OutlinedButton.icon(
                      onPressed: onOpenLocationSettings,
                      icon: const Icon(Icons.location_searching_rounded),
                      label: const Text('Enable Location'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  (String, String) _friendlyMessage(WeatherException? exception) {
    switch (exception?.type) {
      case WeatherErrorType.network:
        return (
          'You appear to be offline',
          'We could not reach the weather services. Retry when your connection returns, or search again to use any saved forecast.',
        );
      case WeatherErrorType.permissionDenied:
      case WeatherErrorType.permissionDeniedForever:
        return (
          'Location access is unavailable',
          'Search for a city manually, or allow location access so the app can load weather near you.',
        );
      case WeatherErrorType.locationDisabled:
        return (
          'Location services are turned off',
          'Turn location services back on to fetch weather for your device position, or search for a city instead.',
        );
      case WeatherErrorType.invalidQuery:
        return (
          'City not found',
          exception?.message ??
              'Check the spelling and try another city, state, or country name.',
        );
      case WeatherErrorType.rateLimited:
        return (
          'Provider limit reached',
          'One weather service refused the request limit. The app can retry and continue through backup providers.',
        );
      default:
        return (
          'Weather could not be loaded',
          exception?.message ??
              'Something unexpected happened while loading the latest forecast.',
        );
    }
  }
}

class _WeatherContentView extends StatelessWidget {
  const _WeatherContentView({
    super.key,
    required this.snapshot,
    required this.searchController,
    required this.detailsExpanded,
    required this.onSearch,
    required this.onRefresh,
    required this.onUseLocation,
    required this.onToggleDetails,
  });

  final WeatherSnapshot snapshot;
  final TextEditingController searchController;
  final bool detailsExpanded;
  final Future<void> Function() onSearch;
  final Future<void> Function() onRefresh;
  final Future<void> Function({bool refresh}) onUseLocation;
  final VoidCallback onToggleDetails;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: const Color(0xFF0D4C92),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          _Header(searchController: searchController, onSearch: onSearch),
          const SizedBox(height: 20),
          if (snapshot.isStale && snapshot.notice != null) ...[
            _StatusBanner(message: snapshot.notice!),
            const SizedBox(height: 18),
          ],
          _CurrentWeatherCard(
            snapshot: snapshot,
            detailsExpanded: detailsExpanded,
            onToggleDetails: onToggleDetails,
          ),
          const SizedBox(height: 18),
          _SectionCard(
            title: 'Hourly Forecast',
            subtitle: 'Next few hours',
            trailing: Text(
              'Source: ${snapshot.providerName}',
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: Colors.white70),
            ),
            child: SizedBox(
              height: 160,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: snapshot.hourly.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final item = snapshot.hourly[index];
                  return _EntranceWrap(
                    delayMs: index * 70,
                    child: _HourlyTile(item: item),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 18),
          _SectionCard(
            title: '5-Day Outlook',
            subtitle: 'Daily trend',
            trailing: TextButton.icon(
              onPressed: () => onUseLocation(refresh: false),
              icon: const Icon(Icons.my_location_rounded),
              label: const Text('My location'),
            ),
            child: Column(
              children: [
                for (var i = 0; i < snapshot.daily.length; i++) ...[
                  _EntranceWrap(
                    delayMs: i * 90,
                    child: _DailyTile(item: snapshot.daily[i]),
                  ),
                  if (i != snapshot.daily.length - 1)
                    Divider(color: Colors.white.withValues(alpha: 0.12)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.searchController, required this.onSearch});

  final TextEditingController searchController;
  final Future<void> Function() onSearch;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SkyCast',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Live forecasts, graceful offline fallback, and polished motion.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.white.withValues(alpha: 0.82),
          ),
        ),
        const SizedBox(height: 18),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: MediaQuery.of(context).size.width - 70,
                child: TextField(
                  controller: searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => onSearch(),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search any city',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Colors.white,
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: onSearch,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF08213B),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
                child: const Text('Go'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CurrentWeatherCard extends StatelessWidget {
  const _CurrentWeatherCard({
    required this.snapshot,
    required this.detailsExpanded,
    required this.onToggleDetails,
  });

  final WeatherSnapshot snapshot;
  final bool detailsExpanded;
  final VoidCallback onToggleDetails;

  @override
  Widget build(BuildContext context) {
    final current = snapshot.current;
    final foreground = current.isDay
        ? const Color(0xFF071B34)
        : const Color(0xFFF4F8FF);
    final secondary = foreground.withValues(alpha: current.isDay ? 0.75 : 0.8);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          colors: current.isDay
              ? const [Color(0xFFD8F3FF), Color(0xFF8BC6EC), Color(0xFF4E89FF)]
              : const [Color(0xFF0B132B), Color(0xFF1C2541), Color(0xFF3A506B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      snapshot.locationName,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: foreground,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      [
                        if (snapshot.region.isNotEmpty) snapshot.region,
                        if (snapshot.country.isNotEmpty) snapshot.country,
                      ].join(', '),
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: secondary),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      DateFormat(
                        'EEE, MMM d • h:mm a',
                      ).format(snapshot.localTime),
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: secondary),
                    ),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                child: Icon(
                  _conditionIcon(current.iconKey, current.isDay),
                  key: ValueKey(current.iconKey + current.isDay.toString()),
                  size: 54,
                  color: const Color(0xFF08213B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (child, animation) => SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.25),
                    end: Offset.zero,
                  ).animate(animation),
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: Text(
                  '${current.temperatureC.round()}°',
                  key: ValueKey(current.temperatureC.round()),
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                    height: 0.95,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Text(
                  current.condition,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Feels like ${current.feelsLikeC.round()}° • Wind ${current.windKph.round()} km/h',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: foreground.withValues(alpha: 0.82),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MetricChip(
                label: 'Humidity',
                value: '${current.humidity}%',
                isDay: current.isDay,
              ),
              _MetricChip(
                label: 'Rain',
                value: '${current.precipitationMm} mm',
                isDay: current.isDay,
              ),
              _MetricChip(
                label: 'Clouds',
                value: '${current.cloud}%',
                isDay: current.isDay,
              ),
              _MetricChip(
                label: 'UV',
                value: current.uvIndex.toStringAsFixed(1),
                isDay: current.isDay,
              ),
            ],
          ),
          const SizedBox(height: 18),
          InkWell(
            onTap: onToggleDetails,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Text(
                    'Today at a glance',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 250),
                    turns: detailsExpanded ? 0.5 : 0,
                    child: const Icon(Icons.keyboard_arrow_down_rounded),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            child: detailsExpanded
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: _DetailBlock(
                            label: 'Forecast source',
                            value: snapshot.providerName,
                            isDay: current.isDay,
                          ),
                        ),
                        Expanded(
                          child: _DetailBlock(
                            label: 'Daily rain chance',
                            value: snapshot.daily.isEmpty
                                ? '--'
                                : '${snapshot.daily.first.chanceOfRain}%',
                            isDay: current.isDay,
                          ),
                        ),
                        Expanded(
                          child: _DetailBlock(
                            label: 'Cache status',
                            value: snapshot.isStale ? 'Offline copy' : 'Live',
                            isDay: current.isDay,
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              trailing,
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _HourlyTile extends StatelessWidget {
  const _HourlyTile({required this.item});

  final HourlyForecast item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 108,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            DateFormat('h a').format(item.time),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.white),
          ),
          Icon(
            _conditionIcon(item.iconKey, true),
            color: Colors.white,
            size: 30,
          ),
          Text(
            '${item.temperatureC.round()}°',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            '${item.chanceOfRain}%',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _DailyTile extends StatelessWidget {
  const _DailyTile({required this.item});

  final DailyForecast item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              DateFormat('EEEE').format(item.date),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Icon(_conditionIcon(item.iconKey, true), color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            flex: 1,
            child: Text(
              '${item.chanceOfRain}%',
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '${item.minTempC.round()}° / ${item.maxTempC.round()}°',
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.value,
    this.isDay = true,
  });

  final String label;
  final String value;
  final bool isDay;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: (isDay ? const Color(0xFF08213B) : Colors.white)
                  .withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: isDay ? const Color(0xFF08213B) : Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailBlock extends StatelessWidget {
  const _DetailBlock({
    required this.label,
    required this.value,
    required this.isDay,
  });

  final String label;
  final String value;
  final bool isDay;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: (isDay ? const Color(0xFF08213B) : Colors.white)
                  .withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: isDay ? const Color(0xFF08213B) : Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.offline_bolt_rounded, color: Color(0xFF8A5D00)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF5B3D00),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseSkeleton extends StatefulWidget {
  const _PulseSkeleton({required this.height});

  final double height;

  @override
  State<_PulseSkeleton> createState() => _PulseSkeletonState();
}

class _PulseSkeletonState extends State<_PulseSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 0.95).animate(_controller),
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(28),
        ),
      ),
    );
  }
}

class _EntranceWrap extends StatefulWidget {
  const _EntranceWrap({required this.delayMs, required this.child});

  final int delayMs;
  final Widget child;

  @override
  State<_EntranceWrap> createState() => _EntranceWrapState();
}

class _EntranceWrapState extends State<_EntranceWrap> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) {
        setState(() => _visible = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      offset: _visible ? Offset.zero : const Offset(0.12, 0),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 450),
        opacity: _visible ? 1 : 0,
        child: widget.child,
      ),
    );
  }
}

IconData _conditionIcon(String condition, bool isDay) {
  final normalized = condition.toLowerCase();
  if (normalized.contains('thunder')) {
    return Icons.thunderstorm_rounded;
  }
  if (normalized.contains('snow') || normalized.contains('ice')) {
    return Icons.ac_unit_rounded;
  }
  if (normalized.contains('rain') || normalized.contains('drizzle')) {
    return Icons.grain_rounded;
  }
  if (normalized.contains('fog') || normalized.contains('mist')) {
    return Icons.blur_on_rounded;
  }
  if (normalized.contains('cloud')) {
    return Icons.cloud_rounded;
  }
  return isDay ? Icons.wb_sunny_rounded : Icons.nightlight_round;
}
