class ApiKeys {
  const ApiKeys._();

  static const weatherApi = String.fromEnvironment(
    'WEATHER_API_KEY',
    defaultValue: '20ce2c185d824591a9a133653262804',
  );

  static const openWeather = String.fromEnvironment(
    'OPENWEATHER_API_KEY',
    defaultValue: 'ff0e9ac7dcf68b85a7d96e2bfb4e1188',
  );

  static const tomorrow = String.fromEnvironment(
    'TOMORROW_API_KEY',
    defaultValue: '83MG4QM6+6M',
  );
}
