# SkyCast Project Walkthrough

This file explains the entire project from the beginning so you can confidently present it to mentors, tutors, or reviewers. It is written as a teaching document, not just a summary.

## 1. What We Built

We built a Flutter `Weather App` named `SkyCast` for Android and iOS.

The app solves four major problems:

1. It fetches real-time weather data from public APIs.
2. It gives users weather by current location or by searched city.
3. It keeps working gracefully when APIs fail or the device goes offline.
4. It feels polished through animations, transitions, and loading states.

## 2. The Build Process From Start To Finish

### Step 1: Start from the default Flutter template

The project initially contained the default Flutter counter app. That starter code had no weather logic, no network layer, no mobile permissions, and no UI relevant to the task.

So the first decision was to replace the sample app with a real structure.

### Step 2: Define the architecture before writing the UI

Instead of writing everything in `main.dart`, the project was split into clear layers:

- `config` for API keys
- `core` for reusable models
- `data` for API calls, cache, repository logic, and error classes
- `services` for location access
- `presentation` for controller state and UI widgets

This was done so each file has one responsibility and the app is easier to maintain, debug, and explain.

### Step 3: Choose provider priority

We deliberately used a provider chain:

1. `WeatherAPI`
2. `OpenWeather`
3. `Tomorrow.io`

Why this order:

- `WeatherAPI` is efficient because one forecast call returns current, hourly, and daily data together.
- `OpenWeather` is a strong backup, but needs two endpoints to rebuild the same experience.
- `Tomorrow.io` is a final safety net and also requires response normalization because it uses weather codes.

### Step 4: Normalize all providers into one internal model

Even though the APIs return different JSON shapes, the app should behave the same no matter which provider answers.

So we created shared internal models:

- `WeatherSnapshot`
- `CurrentWeather`
- `HourlyForecast`
- `DailyForecast`
- `WeatherLoadResult`

Every provider converts its own API response into those same models.

That means the UI never needs to care whether data came from WeatherAPI, OpenWeather, or Tomorrow.io.

### Step 5: Add offline caching

To meet the offline requirement, every successful result is saved locally using `SharedPreferences`.

If all providers fail later:

- the repository checks the cache
- returns the last saved forecast if present
- marks it as stale
- the UI shows a clear offline banner

### Step 6: Add mobile location support

The app uses `geolocator` to:

- detect if location services are enabled
- request permission
- handle denied and permanently denied states
- fetch latitude and longitude

Those coordinates are then passed into the repository for weather lookup.

### Step 7: Build animated UI states

The UI was built around app state, not static screens.

There are three main visual states:

- loading
- error
- loaded content

Those states transition with `AnimatedSwitcher`, which makes the app feel responsive instead of abruptly changing screens.

### Step 8: Verify the result

After implementation:

- packages were installed with `flutter pub get`
- code was formatted
- static analysis was run with `flutter analyze`
- a test was run with `flutter test`

The app finished with passing analysis and passing tests.

## 3. File-By-File Explanation

## `lib/main.dart`

This is the true app entry point.

```dart
import 'package:flutter/widgets.dart';
import 'src/app.dart';

void main() {
  runApp(const SkyCastApp());
}
```

What it does:

- imports Flutter widget support
- imports the root app widget
- starts the app with `runApp`

How it links to the rest of the app:

- `SkyCastApp` is defined in `lib/src/app.dart`
- once `runApp` executes, Flutter begins building the widget tree from there

## `lib/src/app.dart`

This file bootstraps the whole application.

Main responsibilities:

- define theme
- create the repository
- create the controller
- inject dependencies into the home page

Important logic:

```dart
final repository = WeatherRepository(
  providers: [
    WeatherApiProvider(),
    OpenWeatherProvider(),
    TomorrowWeatherProvider(),
  ],
);
```

What this means:

- the app creates a repository
- the repository receives a provider list
- provider order matters
- the repository will try them one after another

Then:

```dart
home: WeatherHomePage(
  controller: WeatherController(
    repository: repository,
    locationService: LocationService(),
  ),
),
```

This links the app together:

- UI gets a `WeatherController`
- controller gets a `WeatherRepository`
- controller also gets `LocationService`

So the dependency chain is:

`UI -> Controller -> Repository -> Provider`

## `lib/src/config/api_keys.dart`

This file stores API key access in one place.

It uses `String.fromEnvironment(...)`.

Why this matters:

- it allows compile-time injection with `--dart-define`
- it also supports default fallback values
- it prevents scattering secrets across many files

Behavior:

- if a runtime define exists, Flutter uses it
- otherwise the fallback value in the file is used

## `lib/src/core/weather_models.dart`

This is one of the most important files in the whole project.

It defines the internal data contract for the app.

### `WeatherSnapshot`

This is the complete weather object the UI consumes.

It contains:

- location details
- current weather
- hourly forecast list
- daily forecast list
- provider name
- query label
- fetched time
- stale status
- optional notice

Why this object exists:

- the UI wants one clean object
- APIs return many different shapes
- this model hides provider differences

### `copyWith`

This method allows us to clone a weather object while changing only a few fields.

Example use:

- when cached data is loaded
- we want to keep all weather values
- but change `isStale` to `true`
- and add a user-facing notice

### `toMap`, `toJson`, `fromJson`

These functions make the model serializable.

Why needed:

- offline cache stores strings
- API results need to be saved and restored

Flow:

1. weather result is converted to JSON
2. JSON is stored in `SharedPreferences`
3. later it is read back and reconstructed

### `CurrentWeather`

Holds current condition details:

- temperature
- feels like
- condition text
- humidity
- wind speed
- UV
- cloud cover
- precipitation
- day/night state

### `HourlyForecast`

Holds a single hour card's data:

- hour time
- temperature
- label
- icon key
- rain chance

### `DailyForecast`

Holds a daily summary row:

- date
- min temperature
- max temperature
- condition
- icon key
- rain chance

### `WeatherLoadResult`

Wraps the final repository result and indicates whether it came from cache.

This avoids forcing the UI to guess.

## `lib/src/data/weather_provider.dart`

This file defines an abstract contract:

```dart
abstract class WeatherProvider {
  String get providerName;
  bool get isConfigured;
  Future<WeatherSnapshot> fetchByQuery(String query);
  Future<WeatherSnapshot> fetchByCoordinates(double latitude, double longitude);
}
```

Why it matters:

- every provider must implement the same methods
- repository can treat providers uniformly
- fallback becomes simple

Without this abstraction, the repository would need custom logic for every provider.

## `lib/src/data/weather_exception.dart`

This file standardizes error handling across the app.

It defines:

- `WeatherErrorType`
- `WeatherException`

Supported error kinds:

- network
- location disabled
- permission denied
- permission denied forever
- invalid query
- rate limited
- authentication
- api
- unknown

Why this is useful:

- APIs fail in different ways
- permission failures are not network failures
- the UI should show the right message for each case

Also important:

```dart
bool get canTryFallback => ...
```

This tells the repository whether it makes sense to try another provider.

Example:

- `rateLimited` should try fallback
- `authentication` should try fallback
- `invalidQuery` should not magically change with another provider, so it stops

## `lib/src/data/weather_cache.dart`

This file handles local persistence.

Main methods:

- `save`
- `read`

How `save` works:

1. gets `SharedPreferences`
2. serializes `WeatherSnapshot`
3. saves the string using a cache key

How `read` works:

1. gets `SharedPreferences`
2. finds the stored string
3. if missing, returns `null`
4. if present, deserializes into `WeatherSnapshot`

Why the `_prefix` exists:

- prevents key collisions
- makes stored values easier to organize

## `lib/src/data/weather_api_provider.dart`

This is the primary provider.

### Constructor

```dart
WeatherApiProvider({http.Client? client}) : _client = client ?? http.Client();
```

Why written like this:

- uses dependency injection
- allows custom clients in testing if needed
- defaults to a normal HTTP client in production

### `providerName`

Returns `WeatherAPI`.

This is used by the UI to show where the data came from.

### `isConfigured`

Checks whether the WeatherAPI key exists.

This lets the repository ignore providers that are not configured.

### `fetchByCoordinates` and `fetchByQuery`

These are thin wrappers around `_fetchWeather(...)`.

Why:

- avoids duplicate code
- query string and coordinates both end up at the same endpoint

### `_fetchWeather`

This is the main method.

First it builds the URI:

```dart
final uri = Uri.https('api.weatherapi.com', '/v1/forecast.json', {
  'key': ApiKeys.weatherApi,
  'q': query,
  'days': '5',
  'aqi': 'no',
  'alerts': 'no',
});
```

What each parameter does:

- `key`: authenticates the request
- `q`: city name or `lat,lon`
- `days=5`: asks for 5 forecast days
- `aqi=no`: skips air quality data we do not display
- `alerts=no`: skips alerts for a lighter payload

Then:

```dart
final response = await _client.get(uri);
```

This sends the HTTP request.

Then:

```dart
final map = _decode(response.body);
```

This converts raw JSON text into a Dart map.

Then the file checks:

- HTTP status code
- whether the API returned an `error` object

If it failed, `_mapError(...)` converts provider-specific error codes into app-specific `WeatherException` objects.

### Mapping hourly data

WeatherAPI returns many hourly entries. The code loops through `forecastday -> hour`.

It keeps only the next few useful hours:

- later than current local time minus one hour
- maximum of 8 entries

Why:

- keeps the UI focused and lightweight
- avoids flooding the horizontal list with too much data

### Mapping daily data

For each forecast day, the code extracts:

- date
- min temp
- max temp
- condition
- rain chance

This becomes the 5-day section in the UI.

### Returned value

At the end, the method returns a fully normalized `WeatherSnapshot`.

This object is what the rest of the app uses.

### Error handling

The provider catches:

- `SocketException` for network failure
- `FormatException` for malformed JSON

It also maps WeatherAPI-specific error codes such as:

- invalid city
- bad API key
- rate limit reached

## `lib/src/data/open_weather_provider.dart`

This file is the first fallback provider.

Why it is more complex than WeatherAPI:

- OpenWeather does not give the complete experience from one endpoint
- current weather and forecast are separate calls

### Request strategy

The provider builds:

- `currentUri`
- `forecastUri`

Then it uses:

```dart
final responses = await Future.wait([...]);
```

Why:

- both requests run in parallel
- this reduces wait time

### Parsing logic

From `/weather` it extracts:

- current temperature
- feels like
- humidity
- wind speed
- weather label

From `/forecast` it extracts:

- 3-hour forecast entries
- city metadata
- timezone offset

### Building hourly data

The app filters upcoming entries and takes several of them for the horizontal hourly strip.

### Building daily data

Since OpenWeather forecast entries come every 3 hours, the code groups entries by day and:

- computes daily min
- computes daily max
- picks a representative weather description
- calculates the highest rain probability for that day

This is a good example of response normalization: the API does not hand us a perfect daily card, so we build one.

## `lib/src/data/tomorrow_weather_provider.dart`

This is the final fallback provider.

It calls:

- `/v4/weather/realtime`
- `/v4/weather/forecast`

### Why two requests again

- realtime gives the current state
- forecast gives hourly and daily timeline blocks

### Unique challenge in Tomorrow.io

Tomorrow often returns numeric weather codes instead of friendly text.

So this file contains:

```dart
String _conditionFromTomorrowCode(int code)
```

This translates weather codes into display labels like:

- Clear
- Cloudy
- Rain
- Snow
- Thunderstorm

Why this matters:

- the UI expects text conditions
- the icon system also relies on readable condition names

## `lib/src/data/weather_repository.dart`

This file coordinates the entire data strategy.

It is the brain of the data layer.

### Constructor

The constructor receives:

- a list of providers
- an optional cache implementation

It filters providers using:

```dart
.where((provider) => provider.isConfigured)
```

That means only providers with keys are considered active.

### `fetchByQuery` and `fetchByCoordinates`

These methods do not call APIs directly. Instead, they build a cache key and pass an action into `_execute(...)`.

This removes duplicate logic.

### `_execute`

This is the critical orchestration method.

Its behavior is:

1. try provider 1
2. if provider 1 succeeds, cache the result and return it
3. if provider 1 fails with a fallback-eligible error, try provider 2
4. if provider 2 fails similarly, try provider 3
5. if all fail, try the cache
6. if cache exists, return stale cached data
7. if cache does not exist, throw the last error

That is the core resilience story of the app.

### Why network errors stop the loop

If the whole device is offline, trying every provider would waste time.

So when the error is `network`, the repository breaks out and checks the cache immediately.

### Why invalid query stops the loop

If the user searches a nonsense city, fallback providers will likely fail too.

So it surfaces the error quickly instead of doing unnecessary requests.

### `_cacheKey`

This method normalizes user query strings into safe, consistent storage keys.

That helps cache results for:

- city names
- coordinate-based lookups

## `lib/src/services/location_service.dart`

This file isolates device location behavior from the UI and repository.

### `getCurrentPosition`

This method:

1. checks if device location services are enabled
2. checks current permission
3. requests permission if needed
4. throws the right `WeatherException` for denial cases
5. returns the GPS position if successful

Why isolate it:

- permission logic is messy
- UI should not know every permission branch
- controller gets a clean interface instead

### `openSettings` and `openLocationSettings`

These support recovery actions from the error UI.

If the user permanently denied permission, we can send them to settings.

## `lib/src/presentation/weather_controller.dart`

This file manages app state.

Think of it as the layer between business logic and widgets.

### Why `ChangeNotifier`

It is simple, built into Flutter, and good enough for this project size.

The UI listens to the controller and rebuilds when `notifyListeners()` is called.

### `WeatherViewState`

This enum defines the main screen modes:

- idle
- loading
- loaded
- error

This makes UI branching explicit and easy to reason about.

### Important properties

- `snapshot`: latest weather data
- `error`: latest failure
- `isRefreshing`: whether the app is refreshing while already showing content
- `detailsExpanded`: controls expanded detail area
- `showingDeviceLocation`: tracks whether current data came from GPS mode
- `activeCityQuery`: remembers the last searched city

### `loadInitial`

Runs only once from the screen's `initState`.

If still idle, it loads current location weather.

### `loadCurrentLocation`

This method:

1. sets state to loading or refresh mode
2. clears previous error
3. requests device location
4. saves latitude and longitude
5. asks repository for weather by coordinates
6. saves result to `snapshot`
7. sets state to loaded

If anything fails, it stores the error and sets state to `error`.

### `searchCity`

This method:

1. trims the input
2. rejects empty input with a user-friendly error
3. sets loading or refresh mode
4. asks repository for query-based weather
5. stores the result in `snapshot`

### `refresh`

This is used by pull-to-refresh.

Behavior:

- if we are in device-location mode, reload location weather
- if we are in search mode, re-run the last search
- if stored coordinates exist, use them

### `retry`

This is used by the error screen.

It repeats the most appropriate last action.

### `toggleDetails`

This changes `detailsExpanded` and updates the UI so the expandable panel animates open or closed.

## `lib/src/presentation/weather_home_page.dart`

This is the biggest UI file. It holds the full weather screen and all the supporting widgets.

## Top-level widget

`WeatherHomePage` is a `StatefulWidget`.

Why stateful:

- it owns a `TextEditingController`
- it triggers the first load in `initState`

### `initState`

```dart
_searchController = TextEditingController();
unawaited(widget.controller.loadInitial());
```

Why `unawaited`:

- `initState` cannot be `async`
- we still want the first weather load to start immediately

### `AnimatedBuilder`

The whole page uses:

```dart
AnimatedBuilder(
  animation: widget.controller,
  builder: ...
)
```

Why:

- `WeatherController` extends `ChangeNotifier`
- every `notifyListeners()` triggers this builder
- the UI stays in sync with app state

### Background gradient logic

`_buildBackgroundGradient(...)` changes the overall atmosphere based on condition text:

- rain and storm -> deeper dramatic blues
- clouds and fog -> muted cloudy tones
- clear weather -> brighter sky tones

This makes the app feel alive and contextual.

## `_buildBody`

This method chooses which UI to render based on controller state.

Cases:

- loading -> `_LoadingView`
- error -> `_ErrorView`
- loaded -> `_WeatherContentView`

This is where state-driven UI becomes clean and maintainable.

## `_LoadingView`

This screen shows:

- the search header
- pulsing skeleton blocks

Why not a spinner alone:

- skeletons suggest layout
- they feel more polished
- they reduce perceived waiting time

## `_ErrorView`

This screen receives a `WeatherException` and converts it into user-friendly copy.

It also shows recovery actions like:

- retry
- use my location
- open app settings
- enable location

This is important because a good error screen should guide the user, not just report failure.

## `_WeatherContentView`

This is the loaded-state screen.

It wraps the content in `RefreshIndicator`, giving pull-to-refresh behavior.

It renders:

- search header
- stale cache banner if needed
- current weather card
- hourly forecast section
- 5-day forecast section

### Stale banner behavior

If repository returned cached data:

- `snapshot.isStale` becomes `true`
- `snapshot.notice` contains a message
- the banner appears above the weather card

## `_Header`

This is the top input area.

It contains:

- app title
- subtitle
- search field
- search button

When the user submits the text or taps `Go`, `_handleSearch()` is called.

## `_CurrentWeatherCard`

This is the hero card.

It shows:

- location name
- region/country
- local time
- weather icon
- temperature
- condition
- feels-like summary
- metric chips
- expandable details

### Dynamic day/night styling

The card computes:

- `foreground`
- `secondary`

based on whether the weather result says it is daytime.

That gives the card better contrast in both bright and dark visual modes.

### `AnimatedContainer`

This smooths card appearance and visual state changes.

### `AnimatedSwitcher`

Used for:

- weather icon
- temperature

Why:

- when data changes, those values animate instead of popping

### `AnimatedSize`

Used for the details section that expands and collapses.

### `AnimatedRotation`

Used for the chevron arrow to indicate expanded state.

## `_SectionCard`

Reusable wrapper for the hourly and daily forecast blocks.

Why this component exists:

- keeps section styling consistent
- reduces repeated container code

## `_HourlyTile`

Each tile shows:

- hour label
- icon
- temperature
- rain chance

These are rendered horizontally in a `ListView.separated`.

## `_DailyTile`

Each row shows:

- weekday
- icon
- rain chance
- min/max temperatures

These rows form the 5-day forecast section.

## `_MetricChip`

This small reusable widget formats summary metrics such as:

- humidity
- rain
- clouds
- UV

## `_DetailBlock`

This is used inside the expandable section of the hero card.

It shows:

- forecast source
- daily rain chance
- cache status

## `_StatusBanner`

Displays the offline/stale data message.

Its purpose is clarity:

- user sees data
- user also knows it may not be fresh

## `_PulseSkeleton`

This widget powers loading placeholders.

It uses:

- `AnimationController`
- `FadeTransition`

The opacity animates between lower and higher values, creating a pulse effect.

## `_EntranceWrap`

This widget animates forecast items into view.

It uses:

- `AnimatedSlide`
- `AnimatedOpacity`

It also accepts `delayMs`, which makes items appear with a staggered effect.

That gives a more premium feel than showing all items at once.

## `_conditionIcon`

This helper translates condition text into Material icons.

Examples:

- thunder -> thunderstorm icon
- snow -> snow icon
- rain -> rain icon
- cloud -> cloud icon
- otherwise -> sun or moon icon

This keeps icon selection simple and provider-independent.

## 4. How The Whole App Behaves At Runtime

Here is the full runtime flow.

### App launch

1. `main.dart` runs
2. `SkyCastApp` is created
3. repository and controller are created
4. `WeatherHomePage` is shown
5. `initState` triggers `loadInitial()`

### Location mode

1. controller asks location service for permission and coordinates
2. repository tries WeatherAPI
3. if WeatherAPI succeeds, data is cached and shown
4. if WeatherAPI fails with fallback-eligible errors, repository tries OpenWeather
5. if OpenWeather also fails, repository tries Tomorrow.io
6. if all live sources fail, repository attempts cached data
7. UI renders result, stale banner, or error screen

### Search mode

1. user enters city
2. controller trims input
3. empty input becomes immediate `invalidQuery` error
4. repository fetches by query
5. UI updates to loading, then loaded or error

### Refresh mode

1. user pulls down to refresh
2. controller decides whether current state is location-based or query-based
3. the correct fetch action is repeated
4. `LinearProgressIndicator` shows while refreshing over existing content

## 5. Why This Structure Is Good For Mentors To Review

This project is strong from a review perspective because it demonstrates:

- API integration from multiple sources
- normalization of inconsistent third-party data
- resilient fallback strategy
- local offline persistence
- location permission handling
- layered architecture
- animation and UI polish
- clean separation of concerns

It is not just a weather screen. It is a small but complete mobile product flow.

## 6. How To Explain The Most Important Design Decisions

If a mentor asks why specific choices were made, you can say:

### Why use WeatherAPI first?

Because it gives the most complete weather experience with the least number of requests.

### Why use fallback providers?

Because API failures, key issues, and rate limits are real-world problems. The fallback chain makes the app more resilient.

### Why normalize all responses into one model?

Because the UI should not know how each provider structures its JSON. Normalization keeps the UI clean.

### Why use SharedPreferences?

Because the task required offline caching, and SharedPreferences is lightweight and appropriate for storing the last successful weather snapshot.

### Why use ChangeNotifier instead of a larger state management package?

Because the app is small enough for `ChangeNotifier`, and it keeps the implementation understandable without unnecessary complexity.

### Why include animations?

Because the task explicitly required them, and they also improve the perceived quality of the experience.

## 7. Final Summary

SkyCast is a well-structured Flutter weather app that:

- fetches live weather data
- supports location and search
- falls back across multiple providers
- caches the latest good result
- handles failure states clearly
- uses animation intentionally

If you want a short explanation for mentors, use this:

`I built a Flutter weather app with a layered architecture, WeatherAPI as the primary source, OpenWeather and Tomorrow.io as fallback providers, SharedPreferences for offline caching, Geolocator for location access, and a ChangeNotifier-driven presentation layer with animated transitions for loading, content, and error states.`
