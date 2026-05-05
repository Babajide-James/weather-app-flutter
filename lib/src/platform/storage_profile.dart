import 'adaptive_platform.dart';

class StorageProfile {
  const StorageProfile({
    required this.platformLabel,
    required this.mechanism,
    required this.offlineBehavior,
  });

  final String platformLabel;
  final String mechanism;
  final String offlineBehavior;

  static StorageProfile fromPlatform(AdaptivePlatform platform) {
    final mechanism = switch (platform.kind) {
      SkyCastPlatformKind.android || SkyCastPlatformKind.ios =>
        'Platform preferences through shared_preferences',
      SkyCastPlatformKind.web =>
        'Browser local storage through shared_preferences',
      SkyCastPlatformKind.windows ||
      SkyCastPlatformKind.macos ||
      SkyCastPlatformKind.linux =>
        'Desktop preferences storage through shared_preferences',
      SkyCastPlatformKind.unknown => 'Flutter preferences storage',
    };

    return StorageProfile(
      platformLabel: platform.label,
      mechanism: mechanism,
      offlineBehavior:
          'Last successful forecasts are cached per city or coordinate query and reused when live providers are unavailable.',
    );
  }
}
