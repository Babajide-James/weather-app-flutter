import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'data/open_weather_provider.dart';
import 'data/tomorrow_weather_provider.dart';
import 'data/weather_api_provider.dart';
import 'data/weather_repository.dart';
import 'presentation/weather_controller.dart';
import 'presentation/weather_home_page.dart';
import 'services/location_service.dart';

class SkyCastApp extends StatelessWidget {
  const SkyCastApp({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = WeatherRepository(
      providers: [
        WeatherApiProvider(),
        OpenWeatherProvider(),
        TomorrowWeatherProvider(),
      ],
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SkyCast',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF06111F),
        textTheme: GoogleFonts.spaceGroteskTextTheme(),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3AA0FF),
          brightness: Brightness.dark,
        ),
      ),
      home: WeatherHomePage(
        controller: WeatherController(
          repository: repository,
          locationService: LocationService(),
        ),
      ),
    );
  }
}
