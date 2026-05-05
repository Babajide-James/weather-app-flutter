import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum SkyCastPlatformKind { android, ios, web, windows, macos, linux, unknown }

class AdaptivePlatform {
  const AdaptivePlatform({
    required this.kind,
    required this.isWeb,
    required this.isDesktop,
    required this.isMobile,
    required this.isWideLayout,
    required this.isDesktopLike,
  });

  final SkyCastPlatformKind kind;
  final bool isWeb;
  final bool isDesktop;
  final bool isMobile;
  final bool isWideLayout;
  final bool isDesktopLike;

  static AdaptivePlatform resolve(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final kind = _platformKind();
    final isDesktop =
        kind == SkyCastPlatformKind.windows ||
        kind == SkyCastPlatformKind.macos ||
        kind == SkyCastPlatformKind.linux;
    final isMobile =
        kind == SkyCastPlatformKind.android || kind == SkyCastPlatformKind.ios;
    final isWideLayout = width >= 980;

    return AdaptivePlatform(
      kind: kind,
      isWeb: kIsWeb,
      isDesktop: isDesktop,
      isMobile: isMobile,
      isWideLayout: isWideLayout,
      isDesktopLike: isDesktop || (kIsWeb && width >= 720),
    );
  }

  static SkyCastPlatformKind _platformKind() {
    if (kIsWeb) {
      return SkyCastPlatformKind.web;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return SkyCastPlatformKind.android;
      case TargetPlatform.iOS:
        return SkyCastPlatformKind.ios;
      case TargetPlatform.windows:
        return SkyCastPlatformKind.windows;
      case TargetPlatform.macOS:
        return SkyCastPlatformKind.macos;
      case TargetPlatform.linux:
        return SkyCastPlatformKind.linux;
      case TargetPlatform.fuchsia:
        return SkyCastPlatformKind.unknown;
    }
  }

  String get label {
    switch (kind) {
      case SkyCastPlatformKind.android:
        return 'Android';
      case SkyCastPlatformKind.ios:
        return 'iOS';
      case SkyCastPlatformKind.web:
        return 'Web';
      case SkyCastPlatformKind.windows:
        return 'Windows';
      case SkyCastPlatformKind.macos:
        return 'macOS';
      case SkyCastPlatformKind.linux:
        return 'Linux';
      case SkyCastPlatformKind.unknown:
        return 'Unknown';
    }
  }
}
