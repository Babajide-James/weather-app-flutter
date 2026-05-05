# SkyCast Weather App

SkyCast is a Flutter weather forecast app built with a single Flutter codebase and platform folders for Android, iOS, web, Windows, macOS, and Linux. It delivers current weather, hourly updates, and a 5-day forecast with animated transitions, offline caching, provider fallback, and user-friendly handling for network and location failures.

## App Type

This repository contains a `Weather App`.

## HNG Platform Adaptation Compliance

This section tracks the final implementation against the multi-platform requirement.

| Requirement | Current status |
| --- | --- |
| Single codebase for mobile, desktop, and web | Done. The app is built from one Flutter codebase with Android, iOS, web, Windows, macOS, and Linux targets. |
| Responsive layouts based on screen size | Done. The UI uses `LayoutBuilder`, `MediaQuery`, constrained content widths, wrap layouts, and a wide-screen two-column forecast layout. It responds to window size, not platform name alone. |
| Platform detection and platform-specific adaptation | Done. `AdaptivePlatform` uses `kIsWeb`, `defaultTargetPlatform`, and screen width to identify mobile, desktop, web, wide layouts, and desktop-like experiences. |
| Multiple input methods and navigation patterns | Done. The app supports touch gestures, pull-to-refresh, text input submission, mouse hover states, right-click menus, keyboard shortcuts, tab traversal, a desktop sidebar, a mobile drawer, and a desktop menu bar. |
| Keyboard shortcuts | Done. The app implements more than five shortcuts through Flutter `Shortcuts` and `Actions`. |
| Mouse hover states | Done. Sidebar actions, hourly forecast tiles, and daily forecast rows include intentional hover feedback for mouse users. |
| Keyboard tab navigation | Done. The app wraps the experience in a `FocusTraversalGroup` and uses focusable Material controls plus a dedicated search focus node for keyboard users. |
| Sidebar or menu-bar navigation | Done. Wide desktop/web layouts include a sidebar, mobile layouts include a drawer, and desktop-like layouts include an application-style `MenuBar`. |
| Shared data layer | Done. The UI uses `WeatherController`, `WeatherRepository`, provider classes, shared weather models, and cache logic across the app. |
| Platform storage and offline functionality | Done. Offline caching uses `shared_preferences`, and `StorageProfile` documents the platform storage mechanism shown inside the app. Cached forecasts are reused when live providers fail. |
| Resizable desktop window content adaptation | Done. Flutter desktop windows are resizable by default, and the content adapts through responsive breakpoints, constrained widths, wrapping content, and wide/narrow layout changes. |
| Desktop application menu: File, Edit, View, Help | Done. Desktop-like layouts show an application-style menu with File, Edit, View, and Help sections. |
| Right-click context menus | Done. The header/search area, current weather card, and forecast sections expose contextual right-click actions. |
| LinkedIn/X documentation post | Ready. A final LinkedIn post is provided outside the project for publishing and tagging the HNG Internship account. |

## Desktop, Web, And Keyboard Features

- Desktop-style application menu with `File`, `Edit`, `View`, and `Help`
- Wide-screen sidebar navigation for Weather, Forecast, Offline, Refresh, and My Location
- Mobile drawer navigation for the same core sections
- Right-click context menus on the search/header area, current weather card, and forecast sections
- Mouse hover feedback on sidebar actions, hourly forecast tiles, and daily forecast rows
- Keyboard-first search focus and tab traversal support

Keyboard shortcuts:

| Shortcut | Action |
| --- | --- |
| `Ctrl/Cmd + R` | Refresh weather |
| `Ctrl/Cmd + L` | Focus search |
| `Ctrl/Cmd + Enter` | Submit search |
| `Ctrl/Cmd + D` | Toggle today's details |
| `Ctrl/Cmd + M` | Use current location |
| `Ctrl/Cmd + F` | Jump to forecast |
| `Esc` | Clear current focus |

## Features

- Current weather display with temperature, condition, humidity, wind speed, cloud cover, rainfall, and UV index
- Current device location weather using mobile GPS permissions
- Manual city search for any supported location
- Hourly forecast cards for the next several hours
- 5-day forecast section for daily weather outlook
- Condition-aware UI with dynamic gradients and icons
- Offline caching of the last successful weather response
- Fallback data providers when the primary API fails
- Loading skeletons, refresh indicator, and dedicated error states
- Retry actions for failed requests
- Expandable weather details panel
- Adaptive platform shell for mobile, desktop, and web
- Desktop menu bar, sidebar navigation, right-click context menus, keyboard shortcuts, and hover states
- In-app offline storage panel showing live/stale cache status and platform storage behavior

## APIs Used

The app consumes weather data in this order:

1. `WeatherAPI` as the primary source
   - Docs: [https://www.weatherapi.com/docs/](https://www.weatherapi.com/docs/)
   - Endpoint used: `https://api.weatherapi.com/v1/forecast.json`

2. `OpenWeather` as the first fallback source
   - Docs: [https://openweathermap.org/api](https://openweathermap.org/api)
   - Endpoints used:
     - `https://api.openweathermap.org/data/2.5/weather`
     - `https://api.openweathermap.org/data/2.5/forecast`

3. `Tomorrow.io` as the final fallback source
   - Docs: [https://www.tomorrow.io/weather-api/](https://www.tomorrow.io/weather-api/)
   - Endpoints used:
     - `https://api.tomorrow.io/v4/weather/realtime`
     - `https://api.tomorrow.io/v4/weather/forecast`

## How The App Consumes The APIs

### Primary flow: WeatherAPI

WeatherAPI is used first because it returns current weather, hourly forecast, and 5-day forecast from a single request. The app sends:

```text
GET /v1/forecast.json?key=API_KEY&q=<city_or_lat_lon>&days=5&aqi=no&alerts=no
```

The response is parsed into:

- `location`
- `current`
- `forecast.forecastday`

Those values are mapped into internal Dart models:

- `WeatherSnapshot`
- `CurrentWeather`
- `HourlyForecast`
- `DailyForecast`

### Fallback flow: OpenWeather

If WeatherAPI fails because of provider-side errors like authentication issues, rate limiting, or API failure, the repository automatically tries OpenWeather.

The app makes two requests:

```text
GET /data/2.5/weather
GET /data/2.5/forecast
```

Why two calls:

- `/weather` gives current conditions
- `/forecast` gives 3-hour interval forecast entries

The app then:

- converts metric temperatures
- reads weather descriptions and wind speed
- groups the 3-hour entries into daily summaries
- extracts several near-future entries for the hourly forecast strip

### Final fallback flow: Tomorrow.io

If both WeatherAPI and OpenWeather fail for supported fallback cases, the repository tries Tomorrow.io.

The app makes two requests:

```text
GET /v4/weather/realtime
GET /v4/weather/forecast
```

Tomorrow.io returns numeric weather codes, so the app maps those codes into readable condition labels like:

- `Clear`
- `Cloudy`
- `Rain`
- `Thunderstorm`

### Offline cache behavior

If all live providers fail, the app checks `SharedPreferences` for the most recent saved forecast for that query or coordinate pair. When cached data exists:

- the app loads the saved snapshot
- marks it as stale
- shows a banner explaining that an offline copy is being displayed

## Animation Highlights

The app includes multiple purposeful animation layers:

- `AnimatedSwitcher` for smooth transitions between loading, error, and loaded states
- `AnimatedContainer` on the main weather card for polished visual response and screen feel
- `AnimatedOpacity` + `AnimatedSlide` for staggered entrance of hourly and daily forecast items
- `AnimatedSize` for expanding and collapsing detailed forecast content
- `AnimatedRotation` for the detail chevron
- `FadeTransition` in loading skeletons for pulsing placeholders
- `AnimatedSwitcher` on the temperature and weather icon for responsive data updates

## Architecture Used

The app uses a lightweight layered architecture:

- `config`
  - API key configuration
- `core`
  - shared domain models
- `data`
  - providers, repository, cache, and error types
- `services`
  - location service
- `presentation`
  - controller and widgets

### Architectural flow

```text
UI -> WeatherController -> WeatherRepository -> Provider chain
UI <- WeatherController <- WeatherSnapshot <- Cache / API response
```

This keeps UI code separated from networking, parsing, caching, and permission logic.

## Libraries / Dependencies

- `http`
  - for REST API requests
- `geolocator`
  - for current device location and permission handling
- `shared_preferences`
  - for offline persistence of weather snapshots
- `intl`
  - for date and time formatting
- `google_fonts`
  - for typography styling
- `flutter_test`
  - for basic test coverage

## Screenshots

### App Showcase

![SkyCast Showcase](docs/assets/skycast-showcase.png)

Visual asset path:

- [`docs/assets/skycast-showcase.png`](./docs/assets/skycast-showcase.png)

## Project Structure

```text
lib/
  main.dart
  src/
    app.dart
    config/
    core/
    data/
    platform/
    presentation/
    services/
test/
docs/assets/
```

## Setup

Install packages:

```bash
flutter pub get
```

Run the app:

```bash
flutter run
```

## API Key Configuration

The project currently reads keys from compile-time variables first and falls back to values in:

- [`lib/src/config/api_keys.dart`](./lib/src/config/api_keys.dart)

Recommended production usage:

```bash
flutter run \
  --dart-define=WEATHER_API_KEY=your_weatherapi_key \
  --dart-define=OPENWEATHER_API_KEY=your_openweather_key \
  --dart-define=TOMORROW_API_KEY=your_tomorrow_key
```

## Verification

Validated with:

- `dart format lib test`
- `flutter analyze`
- `flutter test`
- `flutter build web`
- `flutter build windows`

## Deep Project Walkthrough

For a mentor-friendly explanation of the entire codebase, see:

- [`PROJECT_WALKTHROUGH.md`](./PROJECT_WALKTHROUGH.md)
