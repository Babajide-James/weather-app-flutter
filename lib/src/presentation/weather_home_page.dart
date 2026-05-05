import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/weather_models.dart';
import '../data/weather_exception.dart';
import '../platform/adaptive_platform.dart';
import '../platform/storage_profile.dart';
import 'weather_controller.dart';

const _degree = '\u00B0';

class _RefreshWeatherIntent extends Intent {
  const _RefreshWeatherIntent();
}

class _FocusSearchIntent extends Intent {
  const _FocusSearchIntent();
}

class _SubmitSearchIntent extends Intent {
  const _SubmitSearchIntent();
}

class _ToggleDetailsIntent extends Intent {
  const _ToggleDetailsIntent();
}

class _UseLocationIntent extends Intent {
  const _UseLocationIntent();
}

class _ShowForecastIntent extends Intent {
  const _ShowForecastIntent();
}

class _DismissFocusIntent extends Intent {
  const _DismissFocusIntent();
}

enum _ContextAction {
  refresh,
  focusSearch,
  clearSearch,
  submitSearch,
  useLocation,
  toggleDetails,
  showForecast,
  showOffline,
}

class WeatherHomePage extends StatefulWidget {
  const WeatherHomePage({super.key, required this.controller});

  final WeatherController controller;

  @override
  State<WeatherHomePage> createState() => _WeatherHomePageState();
}

class _WeatherHomePageState extends State<WeatherHomePage> {
  late final TextEditingController _searchController;
  late final ScrollController _scrollController;
  late final FocusNode _searchFocusNode;
  final _headerKey = GlobalKey();
  final _currentKey = GlobalKey();
  final _hourlyKey = GlobalKey();
  final _dailyKey = GlobalKey();
  final _offlineKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _scrollController = ScrollController();
    _searchFocusNode = FocusNode(debugLabel: 'SkyCast search field');
    unawaited(widget.controller.loadInitial());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _searchFocusNode.dispose();
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: _shortcutMap,
      child: Actions(
        actions: {
          _RefreshWeatherIntent: CallbackAction<_RefreshWeatherIntent>(
            onInvoke: (_) {
              unawaited(_refreshWeather());
              return null;
            },
          ),
          _FocusSearchIntent: CallbackAction<_FocusSearchIntent>(
            onInvoke: (_) {
              _focusSearch();
              return null;
            },
          ),
          _SubmitSearchIntent: CallbackAction<_SubmitSearchIntent>(
            onInvoke: (_) {
              unawaited(_handleSearch());
              return null;
            },
          ),
          _ToggleDetailsIntent: CallbackAction<_ToggleDetailsIntent>(
            onInvoke: (_) {
              widget.controller.toggleDetails();
              return null;
            },
          ),
          _UseLocationIntent: CallbackAction<_UseLocationIntent>(
            onInvoke: (_) {
              unawaited(widget.controller.loadCurrentLocation(refresh: false));
              return null;
            },
          ),
          _ShowForecastIntent: CallbackAction<_ShowForecastIntent>(
            onInvoke: (_) {
              _scrollTo(_hourlyKey);
              return null;
            },
          ),
          _DismissFocusIntent: CallbackAction<_DismissFocusIntent>(
            onInvoke: (_) {
              FocusManager.instance.primaryFocus?.unfocus();
              return null;
            },
          ),
        },
        child: FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: AnimatedBuilder(
            animation: widget.controller,
            builder: (context, _) {
              final snapshot = widget.controller.snapshot;
              final platform = AdaptivePlatform.resolve(context);
              return Scaffold(
                drawer: platform.isDesktopLike
                    ? null
                    : _MobileNavigationDrawer(
                        onShowWeather: () => _scrollTo(_currentKey),
                        onShowForecast: () => _scrollTo(_hourlyKey),
                        onShowOffline: () => _scrollTo(_offlineKey),
                        onRefresh: _refreshWeather,
                        onUseLocation: () => widget.controller
                            .loadCurrentLocation(refresh: false),
                      ),
                body: Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: _buildBackgroundGradient(snapshot),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: _WeatherScene(current: snapshot?.current),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.04),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.1),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                    SafeArea(
                      child: Column(
                        children: [
                          if (platform.isDesktopLike)
                            _DesktopMenuBar(
                              onRefresh: _refreshWeather,
                              onFocusSearch: _focusSearch,
                              onSubmitSearch: _handleSearch,
                              onClearSearch: _clearSearch,
                              onUseLocation: () => widget.controller
                                  .loadCurrentLocation(refresh: false),
                              onToggleDetails: widget.controller.toggleDetails,
                              onShowForecast: () => _scrollTo(_hourlyKey),
                              onShowOffline: () => _scrollTo(_offlineKey),
                              onAbout: _showAbout,
                            ),
                          Expanded(
                            child: Stack(
                              children: [
                                Row(
                                  children: [
                                    if (platform.isDesktopLike &&
                                        MediaQuery.sizeOf(context).width >=
                                            1040)
                                      _DesktopSidebar(
                                        platform: platform,
                                        onShowWeather: () =>
                                            _scrollTo(_currentKey),
                                        onShowForecast: () =>
                                            _scrollTo(_hourlyKey),
                                        onShowOffline: () =>
                                            _scrollTo(_offlineKey),
                                        onRefresh: _refreshWeather,
                                        onUseLocation: () => widget.controller
                                            .loadCurrentLocation(
                                              refresh: false,
                                            ),
                                      ),
                                    Expanded(child: _buildBody(context)),
                                  ],
                                ),
                                if (widget.controller.isRefreshing)
                                  const Positioned(
                                    left: 0,
                                    right: 0,
                                    top: 0,
                                    child: LinearProgressIndicator(
                                      minHeight: 3,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Map<ShortcutActivator, Intent> get _shortcutMap {
    final modifier = kIsWeb || defaultTargetPlatform != TargetPlatform.macOS
        ? LogicalKeyboardKey.control
        : LogicalKeyboardKey.meta;

    return {
      SingleActivator(
        LogicalKeyboardKey.keyR,
        control: modifier == LogicalKeyboardKey.control,
        meta: modifier == LogicalKeyboardKey.meta,
      ): const _RefreshWeatherIntent(),
      SingleActivator(
        LogicalKeyboardKey.keyL,
        control: modifier == LogicalKeyboardKey.control,
        meta: modifier == LogicalKeyboardKey.meta,
      ): const _FocusSearchIntent(),
      SingleActivator(
        LogicalKeyboardKey.enter,
        control: modifier == LogicalKeyboardKey.control,
        meta: modifier == LogicalKeyboardKey.meta,
      ): const _SubmitSearchIntent(),
      SingleActivator(
        LogicalKeyboardKey.keyD,
        control: modifier == LogicalKeyboardKey.control,
        meta: modifier == LogicalKeyboardKey.meta,
      ): const _ToggleDetailsIntent(),
      SingleActivator(
        LogicalKeyboardKey.keyM,
        control: modifier == LogicalKeyboardKey.control,
        meta: modifier == LogicalKeyboardKey.meta,
      ): const _UseLocationIntent(),
      SingleActivator(
        LogicalKeyboardKey.keyF,
        control: modifier == LogicalKeyboardKey.control,
        meta: modifier == LogicalKeyboardKey.meta,
      ): const _ShowForecastIntent(),
      const SingleActivator(LogicalKeyboardKey.escape):
          const _DismissFocusIntent(),
    };
  }

  Future<void> _refreshWeather() => widget.controller.refresh();

  void _focusSearch() {
    _scrollTo(_headerKey);
    _searchFocusNode.requestFocus();
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocusNode.requestFocus();
  }

  void _scrollTo(GlobalKey key) {
    final context = key.currentContext;
    if (context == null) {
      return;
    }
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'SkyCast',
      applicationVersion: '1.0.0',
      applicationLegalese:
          'Adaptive Flutter weather app with shared data and offline cache.',
      children: const [
        SizedBox(height: 12),
        Text(
          'Built for mobile, desktop, and web with responsive layouts, keyboard shortcuts, menus, right-click actions, and platform-aware storage documentation.',
        ),
      ],
    );
  }

  Future<void> _showHeaderContextMenu(TapDownDetails details) async {
    final selected = await showMenu<_ContextAction>(
      context: context,
      position: _menuPosition(details.globalPosition),
      items: const [
        PopupMenuItem(
          value: _ContextAction.focusSearch,
          child: Text('Focus search'),
        ),
        PopupMenuItem(
          value: _ContextAction.clearSearch,
          child: Text('Clear search'),
        ),
        PopupMenuItem(
          value: _ContextAction.submitSearch,
          child: Text('Search city'),
        ),
      ],
    );
    switch (selected) {
      case _ContextAction.focusSearch:
        _focusSearch();
      case _ContextAction.clearSearch:
        _clearSearch();
      case _ContextAction.submitSearch:
        await _handleSearch();
      case null:
      case _ContextAction.refresh:
      case _ContextAction.useLocation:
      case _ContextAction.toggleDetails:
      case _ContextAction.showForecast:
      case _ContextAction.showOffline:
        break;
    }
  }

  Future<void> _showWeatherContextMenu(TapDownDetails details) async {
    final selected = await showMenu<_ContextAction>(
      context: context,
      position: _menuPosition(details.globalPosition),
      items: const [
        PopupMenuItem(value: _ContextAction.refresh, child: Text('Refresh')),
        PopupMenuItem(
          value: _ContextAction.useLocation,
          child: Text('Use current location'),
        ),
        PopupMenuItem(
          value: _ContextAction.toggleDetails,
          child: Text('Toggle today details'),
        ),
        PopupMenuItem(
          value: _ContextAction.showForecast,
          child: Text('Show forecast'),
        ),
      ],
    );
    switch (selected) {
      case _ContextAction.refresh:
        await _refreshWeather();
      case _ContextAction.useLocation:
        await widget.controller.loadCurrentLocation(refresh: false);
      case _ContextAction.toggleDetails:
        widget.controller.toggleDetails();
      case _ContextAction.showForecast:
        _scrollTo(_hourlyKey);
      case null:
      case _ContextAction.focusSearch:
      case _ContextAction.clearSearch:
      case _ContextAction.submitSearch:
      case _ContextAction.showOffline:
        break;
    }
  }

  Future<void> _showForecastContextMenu(TapDownDetails details) async {
    final selected = await showMenu<_ContextAction>(
      context: context,
      position: _menuPosition(details.globalPosition),
      items: const [
        PopupMenuItem(
          value: _ContextAction.refresh,
          child: Text('Refresh forecast'),
        ),
        PopupMenuItem(
          value: _ContextAction.showOffline,
          child: Text('Show offline status'),
        ),
        PopupMenuItem(
          value: _ContextAction.focusSearch,
          child: Text('Search another city'),
        ),
      ],
    );
    switch (selected) {
      case _ContextAction.refresh:
        await _refreshWeather();
      case _ContextAction.showOffline:
        _scrollTo(_offlineKey);
      case _ContextAction.focusSearch:
        _focusSearch();
      case null:
      case _ContextAction.clearSearch:
      case _ContextAction.submitSearch:
      case _ContextAction.useLocation:
      case _ContextAction.toggleDetails:
      case _ContextAction.showForecast:
        break;
    }
  }

  RelativeRect _menuPosition(Offset globalPosition) {
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    return RelativeRect.fromRect(
      Rect.fromPoints(globalPosition, globalPosition),
      Offset.zero & overlay.size,
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (widget.controller.state) {
      case WeatherViewState.idle:
      case WeatherViewState.loading:
        return _LoadingView(
          key: const ValueKey('loading'),
          scrollController: _scrollController,
          searchController: _searchController,
          searchFocusNode: _searchFocusNode,
          headerKey: _headerKey,
          onSearch: _handleSearch,
          onHeaderContextMenu: _showHeaderContextMenu,
        );
      case WeatherViewState.error:
        return _ErrorView(
          key: const ValueKey('error'),
          scrollController: _scrollController,
          searchController: _searchController,
          searchFocusNode: _searchFocusNode,
          headerKey: _headerKey,
          error: widget.controller.error,
          onRetry: widget.controller.retry,
          onSearch: _handleSearch,
          onCurrentLocation: widget.controller.loadCurrentLocation,
          onOpenSettings: widget.controller.openAppSettings,
          onOpenLocationSettings: widget.controller.openLocationSettings,
          onHeaderContextMenu: _showHeaderContextMenu,
        );
      case WeatherViewState.loaded:
        final snapshot = widget.controller.snapshot!;
        return _WeatherContentView(
          key: const ValueKey('content'),
          scrollController: _scrollController,
          snapshot: snapshot,
          searchController: _searchController,
          searchFocusNode: _searchFocusNode,
          headerKey: _headerKey,
          currentKey: _currentKey,
          hourlyKey: _hourlyKey,
          dailyKey: _dailyKey,
          offlineKey: _offlineKey,
          detailsExpanded: widget.controller.detailsExpanded,
          onSearch: _handleSearch,
          onRefresh: widget.controller.refresh,
          onUseLocation: widget.controller.loadCurrentLocation,
          onToggleDetails: widget.controller.toggleDetails,
          onHeaderContextMenu: _showHeaderContextMenu,
          onWeatherContextMenu: _showWeatherContextMenu,
          onForecastContextMenu: _showForecastContextMenu,
        );
    }
  }

  Future<void> _handleSearch() async {
    FocusScope.of(context).unfocus();
    await widget.controller.searchCity(_searchController.text);
  }

  LinearGradient _buildBackgroundGradient(WeatherSnapshot? snapshot) {
    final current = snapshot?.current;
    final condition = current?.condition.toLowerCase() ?? '';

    if (condition.contains('thunder')) {
      return const LinearGradient(
        colors: [Color(0xFF081526), Color(0xFF16324F), Color(0xFF2F6D89)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
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
    if (current != null && !current.isDay) {
      return const LinearGradient(
        colors: [Color(0xFF050B16), Color(0xFF10213C), Color(0xFF223D67)],
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

class _DesktopMenuBar extends StatelessWidget {
  const _DesktopMenuBar({
    required this.onRefresh,
    required this.onFocusSearch,
    required this.onSubmitSearch,
    required this.onClearSearch,
    required this.onUseLocation,
    required this.onToggleDetails,
    required this.onShowForecast,
    required this.onShowOffline,
    required this.onAbout,
  });

  final Future<void> Function() onRefresh;
  final VoidCallback onFocusSearch;
  final Future<void> Function() onSubmitSearch;
  final VoidCallback onClearSearch;
  final Future<void> Function() onUseLocation;
  final VoidCallback onToggleDetails;
  final VoidCallback onShowForecast;
  final VoidCallback onShowOffline;
  final VoidCallback onAbout;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF071B34).withValues(alpha: 0.82),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: MenuBar(
          style: MenuStyle(
            backgroundColor: WidgetStateProperty.all(Colors.transparent),
            padding: WidgetStateProperty.all(
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
          ),
          children: [
            SubmenuButton(
              menuChildren: [
                MenuItemButton(
                  leadingIcon: const Icon(Icons.refresh_rounded),
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.keyR,
                    control: true,
                  ),
                  onPressed: () => unawaited(onRefresh()),
                  child: const Text('Refresh Weather'),
                ),
                MenuItemButton(
                  leadingIcon: const Icon(Icons.search_rounded),
                  onPressed: onFocusSearch,
                  child: const Text('Search City'),
                ),
                MenuItemButton(
                  leadingIcon: const Icon(Icons.my_location_rounded),
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.keyM,
                    control: true,
                  ),
                  onPressed: () => unawaited(onUseLocation()),
                  child: const Text('Use Current Location'),
                ),
              ],
              child: const Text('File'),
            ),
            SubmenuButton(
              menuChildren: [
                MenuItemButton(
                  leadingIcon: const Icon(Icons.center_focus_strong_rounded),
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.keyL,
                    control: true,
                  ),
                  onPressed: onFocusSearch,
                  child: const Text('Focus Search'),
                ),
                MenuItemButton(
                  leadingIcon: const Icon(Icons.backspace_outlined),
                  onPressed: onClearSearch,
                  child: const Text('Clear Search'),
                ),
                MenuItemButton(
                  leadingIcon: const Icon(Icons.keyboard_return_rounded),
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.enter,
                    control: true,
                  ),
                  onPressed: () => unawaited(onSubmitSearch()),
                  child: const Text('Submit Search'),
                ),
              ],
              child: const Text('Edit'),
            ),
            SubmenuButton(
              menuChildren: [
                MenuItemButton(
                  leadingIcon: const Icon(Icons.expand_circle_down_outlined),
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.keyD,
                    control: true,
                  ),
                  onPressed: onToggleDetails,
                  child: const Text('Toggle Details'),
                ),
                MenuItemButton(
                  leadingIcon: const Icon(Icons.view_timeline_outlined),
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.keyF,
                    control: true,
                  ),
                  onPressed: onShowForecast,
                  child: const Text('Show Forecast'),
                ),
                MenuItemButton(
                  leadingIcon: const Icon(Icons.offline_bolt_outlined),
                  onPressed: onShowOffline,
                  child: const Text('Show Offline Status'),
                ),
              ],
              child: const Text('View'),
            ),
            SubmenuButton(
              menuChildren: [
                MenuItemButton(
                  leadingIcon: const Icon(Icons.info_outline_rounded),
                  onPressed: onAbout,
                  child: const Text('About SkyCast'),
                ),
              ],
              child: const Text('Help'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({
    required this.platform,
    required this.onShowWeather,
    required this.onShowForecast,
    required this.onShowOffline,
    required this.onRefresh,
    required this.onUseLocation,
  });

  final AdaptivePlatform platform;
  final VoidCallback onShowWeather;
  final VoidCallback onShowForecast;
  final VoidCallback onShowOffline;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onUseLocation;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 232,
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
      decoration: BoxDecoration(
        color: const Color(0xFF06111F).withValues(alpha: 0.7),
        border: Border(
          right: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'SkyCast',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${platform.label} adaptive layout',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 24),
          _NavButton(
            icon: Icons.cloud_queue_rounded,
            label: 'Weather',
            onPressed: onShowWeather,
          ),
          _NavButton(
            icon: Icons.calendar_month_rounded,
            label: 'Forecast',
            onPressed: onShowForecast,
          ),
          _NavButton(
            icon: Icons.offline_bolt_rounded,
            label: 'Offline',
            onPressed: onShowOffline,
          ),
          const Spacer(),
          _NavButton(
            icon: Icons.refresh_rounded,
            label: 'Refresh',
            onPressed: () => unawaited(onRefresh()),
          ),
          _NavButton(
            icon: Icons.my_location_rounded,
            label: 'My Location',
            onPressed: () => unawaited(onUseLocation()),
          ),
        ],
      ),
    );
  }
}

class _MobileNavigationDrawer extends StatelessWidget {
  const _MobileNavigationDrawer({
    required this.onShowWeather,
    required this.onShowForecast,
    required this.onShowOffline,
    required this.onRefresh,
    required this.onUseLocation,
  });

  final VoidCallback onShowWeather;
  final VoidCallback onShowForecast;
  final VoidCallback onShowOffline;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onUseLocation;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            ListTile(
              leading: const Icon(Icons.cloud_queue_rounded),
              title: const Text('Weather'),
              onTap: () {
                Navigator.pop(context);
                onShowWeather();
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month_rounded),
              title: const Text('Forecast'),
              onTap: () {
                Navigator.pop(context);
                onShowForecast();
              },
            ),
            ListTile(
              leading: const Icon(Icons.offline_bolt_rounded),
              title: const Text('Offline'),
              onTap: () {
                Navigator.pop(context);
                onShowOffline();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.refresh_rounded),
              title: const Text('Refresh'),
              onTap: () {
                Navigator.pop(context);
                unawaited(onRefresh());
              },
            ),
            ListTile(
              leading: const Icon(Icons.my_location_rounded),
              title: const Text('Use Current Location'),
              onTap: () {
                Navigator.pop(context);
                unawaited(onUseLocation());
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatefulWidget {
  const _NavButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            alignment: Alignment.centerLeft,
            backgroundColor: _hovered
                ? Colors.white.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.1),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
          onPressed: widget.onPressed,
          icon: Icon(widget.icon),
          label: Text(widget.label),
        ),
      ),
    );
  }
}

class _ContextMenuRegion extends StatelessWidget {
  const _ContextMenuRegion({required this.child, required this.onContextMenu});

  final Widget child;
  final Future<void> Function(TapDownDetails details) onContextMenu;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapDown: (details) => unawaited(onContextMenu(details)),
      child: child,
    );
  }
}

class _OfflineStoragePanel extends StatelessWidget {
  const _OfflineStoragePanel({super.key, required this.snapshot});

  final WeatherSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final profile = StorageProfile.fromPlatform(
      AdaptivePlatform.resolve(context),
    );
    return _SectionCard(
      title: 'Offline & Storage',
      subtitle: '${profile.platformLabel} storage profile',
      trailing: Icon(
        snapshot.isStale
            ? Icons.offline_bolt_rounded
            : Icons.cloud_done_rounded,
        color: Colors.white,
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _DetailBlock(
            label: 'Cache',
            value: snapshot.isStale ? 'Offline copy' : 'Live data',
            isDay: false,
          ),
          _DetailBlock(
            label: 'Storage',
            value: profile.mechanism,
            isDay: false,
          ),
          _DetailBlock(
            label: 'Fetched',
            value: DateFormat('MMM d, h:mm a').format(snapshot.fetchedAt),
            isDay: false,
          ),
          Text(
            profile.offlineBehavior,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _HoverSurface extends StatefulWidget {
  const _HoverSurface({
    required this.child,
    this.borderRadius = 18,
    this.hoverScale = 1.015,
  });

  final Widget child;
  final double borderRadius;
  final double hoverScale;

  @override
  State<_HoverSurface> createState() => _HoverSurfaceState();
}

class _HoverSurfaceState extends State<_HoverSurface> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? widget.hoverScale : 1,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.14),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : const [],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class _ResponsiveScrollView extends StatelessWidget {
  const _ResponsiveScrollView({
    required this.children,
    required this.controller,
    this.physics,
  });

  final List<Widget> children;
  final ScrollController controller;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final maxContentWidth = width >= 1440
            ? 1260.0
            : width >= 1100
            ? 1120.0
            : 760.0;
        final horizontalPadding = width >= 1100 ? 32.0 : 20.0;

        return ListView(
          controller: controller,
          physics: physics,
          padding: EdgeInsets.zero,
          children: [
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContentWidth),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    20,
                    horizontalPadding,
                    32,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView({
    super.key,
    required this.scrollController,
    required this.searchController,
    required this.searchFocusNode,
    required this.headerKey,
    required this.onSearch,
    required this.onHeaderContextMenu,
  });

  final ScrollController scrollController;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final GlobalKey headerKey;
  final Future<void> Function() onSearch;
  final Future<void> Function(TapDownDetails details) onHeaderContextMenu;

  @override
  Widget build(BuildContext context) {
    return _ResponsiveScrollView(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _Header(
          key: headerKey,
          searchController: searchController,
          searchFocusNode: searchFocusNode,
          onSearch: onSearch,
          onContextMenu: onHeaderContextMenu,
        ),
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
    required this.scrollController,
    required this.searchController,
    required this.searchFocusNode,
    required this.headerKey,
    required this.error,
    required this.onRetry,
    required this.onSearch,
    required this.onCurrentLocation,
    required this.onOpenSettings,
    required this.onOpenLocationSettings,
    required this.onHeaderContextMenu,
  });

  final ScrollController scrollController;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final GlobalKey headerKey;
  final WeatherException? error;
  final Future<void> Function() onRetry;
  final Future<void> Function() onSearch;
  final Future<void> Function({bool refresh}) onCurrentLocation;
  final Future<void> Function() onOpenSettings;
  final Future<void> Function() onOpenLocationSettings;
  final Future<void> Function(TapDownDetails details) onHeaderContextMenu;

  @override
  Widget build(BuildContext context) {
    final message = _friendlyMessage(error);
    return _ResponsiveScrollView(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _Header(
          key: headerKey,
          searchController: searchController,
          searchFocusNode: searchFocusNode,
          onSearch: onSearch,
          onContextMenu: onHeaderContextMenu,
        ),
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
    required this.scrollController,
    required this.snapshot,
    required this.searchController,
    required this.searchFocusNode,
    required this.headerKey,
    required this.currentKey,
    required this.hourlyKey,
    required this.dailyKey,
    required this.offlineKey,
    required this.detailsExpanded,
    required this.onSearch,
    required this.onRefresh,
    required this.onUseLocation,
    required this.onToggleDetails,
    required this.onHeaderContextMenu,
    required this.onWeatherContextMenu,
    required this.onForecastContextMenu,
  });

  final ScrollController scrollController;
  final WeatherSnapshot snapshot;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final GlobalKey headerKey;
  final GlobalKey currentKey;
  final GlobalKey hourlyKey;
  final GlobalKey dailyKey;
  final GlobalKey offlineKey;
  final bool detailsExpanded;
  final Future<void> Function() onSearch;
  final Future<void> Function() onRefresh;
  final Future<void> Function({bool refresh}) onUseLocation;
  final VoidCallback onToggleDetails;
  final Future<void> Function(TapDownDetails details) onHeaderContextMenu;
  final Future<void> Function(TapDownDetails details) onWeatherContextMenu;
  final Future<void> Function(TapDownDetails details) onForecastContextMenu;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 980;

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: const Color(0xFF0D4C92),
      child: _ResponsiveScrollView(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _Header(
            key: headerKey,
            searchController: searchController,
            searchFocusNode: searchFocusNode,
            onSearch: onSearch,
            onContextMenu: onHeaderContextMenu,
          ),
          const SizedBox(height: 20),
          if (snapshot.isStale && snapshot.notice != null) ...[
            _StatusBanner(message: snapshot.notice!),
            const SizedBox(height: 18),
          ],
          _ContextMenuRegion(
            onContextMenu: onWeatherContextMenu,
            child: _CurrentWeatherCard(
              key: currentKey,
              snapshot: snapshot,
              detailsExpanded: detailsExpanded,
              onToggleDetails: onToggleDetails,
            ),
          ),
          const SizedBox(height: 18),
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 6,
                  child: _buildHourlySection(context, hourlyKey),
                ),
                const SizedBox(width: 18),
                Expanded(flex: 5, child: _buildDailySection(context, dailyKey)),
              ],
            )
          else ...[
            _buildHourlySection(context, hourlyKey),
            const SizedBox(height: 18),
            _buildDailySection(context, dailyKey),
          ],
          const SizedBox(height: 18),
          _OfflineStoragePanel(key: offlineKey, snapshot: snapshot),
        ],
      ),
    );
  }

  Widget _buildHourlySection(BuildContext context, GlobalKey key) {
    return _ContextMenuRegion(
      onContextMenu: onForecastContextMenu,
      child: _SectionCard(
        key: key,
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
    );
  }

  Widget _buildDailySection(BuildContext context, GlobalKey key) {
    return _ContextMenuRegion(
      onContextMenu: onForecastContextMenu,
      child: _SectionCard(
        key: key,
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
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    super.key,
    required this.searchController,
    required this.searchFocusNode,
    required this.onSearch,
    required this.onContextMenu,
  });

  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final Future<void> Function() onSearch;
  final Future<void> Function(TapDownDetails details) onContextMenu;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useInlineSearch = constraints.maxWidth >= 720;

        return _ContextMenuRegion(
          onContextMenu: onContextMenu,
          child: Column(
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
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Text(
                  'Live forecasts, graceful offline fallback, and polished motion.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.82),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              if (useInlineSearch)
                Row(
                  children: [
                    Expanded(
                      child: _SearchField(
                        controller: searchController,
                        focusNode: searchFocusNode,
                        onSearch: onSearch,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _SearchButton(onSearch: onSearch),
                  ],
                )
              else ...[
                _SearchField(
                  controller: searchController,
                  focusNode: searchFocusNode,
                  onSearch: onSearch,
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _SearchButton(onSearch: onSearch),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _CurrentWeatherCard extends StatelessWidget {
  const _CurrentWeatherCard({
    super.key,
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
    final accentColor = current.isDay
        ? const Color(0xFF08213B)
        : const Color(0xFFDDE8FF);
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
                        'EEE, MMM d - h:mm a',
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
                  color: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 12,
            runSpacing: 8,
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
                  '${current.temperatureC.round()}$_degree',
                  key: ValueKey(current.temperatureC.round()),
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                    height: 0.95,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
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
            'Feels like ${current.feelsLikeC.round()}$_degree | Wind ${current.windKph.round()} km/h',
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
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: accentColor,
                    ),
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
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _DetailBlock(
                          label: 'Forecast source',
                          value: snapshot.providerName,
                          isDay: current.isDay,
                        ),
                        _DetailBlock(
                          label: 'Daily rain chance',
                          value: snapshot.daily.isEmpty
                              ? '--'
                              : '${snapshot.daily.first.chanceOfRain}%',
                          isDay: current.isDay,
                        ),
                        _DetailBlock(
                          label: 'Cache status',
                          value: snapshot.isStale ? 'Offline copy' : 'Live',
                          isDay: current.isDay,
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
    super.key,
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compactHeader = constraints.maxWidth < 520;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (compactHeader) ...[
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
                const SizedBox(height: 14),
                trailing,
              ] else
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            subtitle,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    trailing,
                  ],
                ),
              const SizedBox(height: 18),
              child,
            ],
          );
        },
      ),
    );
  }
}

class _HourlyTile extends StatelessWidget {
  const _HourlyTile({required this.item});

  final HourlyForecast item;

  @override
  Widget build(BuildContext context) {
    return _HoverSurface(
      borderRadius: 22,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        width: 108,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
              '${item.temperatureC.round()}$_degree',
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
      ),
    );
  }
}

class _DailyTile extends StatelessWidget {
  const _DailyTile({required this.item});

  final DailyForecast item;

  @override
  Widget build(BuildContext context) {
    return _HoverSurface(
      hoverScale: 1.006,
      child: Padding(
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
                '${item.minTempC.round()}$_degree / ${item.maxTempC.round()}$_degree',
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
    final foreground = isDay ? const Color(0xFF08213B) : Colors.white;
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
              color: foreground.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: foreground,
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
    final foreground = isDay ? const Color(0xFF08213B) : Colors.white;
    return Container(
      constraints: const BoxConstraints(minWidth: 148),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: foreground.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: foreground,
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

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onSearch,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Future<void> Function() onSearch;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => onSearch(),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'Search any city',
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
        prefixIcon: const Icon(Icons.search_rounded, color: Colors.white),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _SearchButton extends StatelessWidget {
  const _SearchButton({required this.onSearch});

  final Future<void> Function() onSearch;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onSearch,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF08213B),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      child: const Text('Go'),
    );
  }
}

class _WeatherScene extends StatefulWidget {
  const _WeatherScene({this.current});

  final CurrentWeather? current;

  @override
  State<_WeatherScene> createState() => _WeatherSceneState();
}

class _WeatherSceneState extends State<_WeatherScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: _WeatherScenePainter(
                current: widget.current,
                phase: _controller.value,
              ),
              child: const SizedBox.expand(),
            );
          },
        ),
      ),
    );
  }
}

class _WeatherScenePainter extends CustomPainter {
  _WeatherScenePainter({required this.current, required this.phase});

  final CurrentWeather? current;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final normalized = current?.condition.toLowerCase() ?? '';
    final isDay = current?.isDay ?? true;
    final isStorm = normalized.contains('thunder');
    final isRain =
        isStorm ||
        normalized.contains('rain') ||
        normalized.contains('drizzle');
    final isFog = normalized.contains('fog') || normalized.contains('mist');
    final isCloudy = normalized.contains('cloud') || isFog || isRain;

    _paintAura(canvas, size, isDay: isDay, isStorm: isStorm);
    _paintOrbitalGlow(canvas, size, isDay: isDay);
    _paintClouds(canvas, size, dense: isCloudy, moody: isStorm || isFog);

    if (!isDay) {
      _paintStars(canvas, size);
    }
    if (isRain) {
      _paintRain(canvas, size, heavy: isStorm);
    }
    if (isFog) {
      _paintFog(canvas, size);
    }
  }

  void _paintAura(
    Canvas canvas,
    Size size, {
    required bool isDay,
    required bool isStorm,
  }) {
    final center = Offset(size.width * 0.78, size.height * 0.16);
    final color = isStorm
        ? const Color(0x66D5ECFF)
        : isDay
        ? const Color(0x55FFF2B8)
        : const Color(0x448DB8FF);
    canvas.drawCircle(
      center,
      size.shortestSide * 0.32,
      Paint()
        ..shader = RadialGradient(colors: [color, Colors.transparent])
            .createShader(
              Rect.fromCircle(center: center, radius: size.shortestSide * 0.32),
            ),
    );
  }

  void _paintOrbitalGlow(Canvas canvas, Size size, {required bool isDay}) {
    final base = Offset(size.width * 0.82, size.height * 0.14);
    final drift = math.sin(phase * math.pi * 2) * 10;
    final center = base.translate(0, drift);
    final radius = isDay ? size.shortestSide * 0.09 : size.shortestSide * 0.06;
    final color = isDay ? const Color(0xFFFFF6C2) : const Color(0xFFF0F4FF);

    canvas.drawCircle(
      center,
      radius,
      Paint()..color = color.withValues(alpha: isDay ? 0.88 : 0.72),
    );
    canvas.drawCircle(
      center,
      radius * 2.4,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: 0.24), Colors.transparent],
        ).createShader(Rect.fromCircle(center: center, radius: radius * 2.4)),
    );
  }

  void _paintClouds(
    Canvas canvas,
    Size size, {
    required bool dense,
    required bool moody,
  }) {
    final alpha = dense ? 0.18 : 0.1;
    final color = moody ? const Color(0xFFC6D5E8) : const Color(0xFFEAF4FF);
    final cloudPaint = Paint()..color = color.withValues(alpha: alpha);
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: moody ? 0.1 : 0.05);

    const clouds = [
      (0.12, 0.16, 150.0, 0.0),
      (0.56, 0.24, 210.0, math.pi / 2),
      (0.28, 0.46, 180.0, math.pi),
    ];

    for (final cloud in clouds) {
      final dx = math.sin(phase * math.pi * 2 + cloud.$4) * 18;
      final center = Offset(size.width * cloud.$1 + dx, size.height * cloud.$2);
      final width = math.min(cloud.$3, size.width * 0.34);
      _paintCloud(canvas, center.translate(0, 8), width, shadowPaint);
      _paintCloud(canvas, center, width, cloudPaint);
    }
  }

  void _paintCloud(Canvas canvas, Offset center, double width, Paint paint) {
    final height = width * 0.34;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: center.translate(0, height * 0.18),
            width: width,
            height: height,
          ),
          Radius.circular(height * 0.5),
        ),
      );
    canvas.drawCircle(center.translate(-width * 0.22, 0), height * 0.42, paint);
    canvas.drawCircle(
      center.translate(0, -height * 0.12),
      height * 0.52,
      paint,
    );
    canvas.drawCircle(center.translate(width * 0.22, 0), height * 0.36, paint);
    canvas.drawPath(path, paint);
  }

  void _paintRain(Canvas canvas, Size size, {required bool heavy}) {
    final rainPaint = Paint()
      ..color = const Color(0xCCCEE9FF)
      ..strokeWidth = heavy ? 2.2 : 1.4
      ..strokeCap = StrokeCap.round;
    final columns = heavy ? 34 : 22;

    for (var i = 0; i < columns; i++) {
      final progress = ((phase * 1.8) + (i / columns)) % 1;
      final x = size.width * (i / columns);
      final y = size.height * progress;
      final length = heavy ? 28.0 : 20.0;
      canvas.drawLine(
        Offset(x, y),
        Offset(x - length * 0.28, y + length),
        rainPaint,
      );
    }
  }

  void _paintFog(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE8F4FF).withValues(alpha: 0.09);
    for (var i = 0; i < 3; i++) {
      final y = size.height * (0.2 + i * 0.16);
      final drift = math.sin((phase * math.pi * 2) + i) * 18;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-40 + drift, y, size.width + 80, 34),
          const Radius.circular(28),
        ),
        paint,
      );
    }
  }

  void _paintStars(Canvas canvas, Size size) {
    final starPaint = Paint()..color = Colors.white.withValues(alpha: 0.75);
    for (var i = 0; i < 16; i++) {
      final x = size.width * ((i * 37 % 100) / 100);
      final y = size.height * ((i * 19 % 28) / 100 + 0.04);
      final pulse = 0.65 + (math.sin((phase * math.pi * 2 * 1.6) + i) * 0.25);
      canvas.drawCircle(Offset(x, y), 1.2 + pulse, starPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WeatherScenePainter oldDelegate) {
    return oldDelegate.phase != phase || oldDelegate.current != current;
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
