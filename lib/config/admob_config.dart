import 'package:flutter/foundation.dart';

class AdMobConfig {
  // Keep test ads enabled in debug/profile builds.
  static const bool useTestAds = !kReleaseMode;

  // Replace these with your real banner IDs before release.
  static const String _androidProdBanner = 'ca-app-pub-9327215418607539/9425918740';
  static const String _iosProdBanner = 'ca-app-pub-xxxxxxxxxxxxxxxx/yyyyyyyyyy';

  // Google-provided test banner IDs.
  static const String _androidTestBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const String _iosTestBanner = 'ca-app-pub-3940256099942544/2934735716';

  static String get bannerAdUnitId {
    if (kIsWeb) return '';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return useTestAds ? _androidTestBanner : _androidProdBanner;
      case TargetPlatform.iOS:
        return useTestAds ? _iosTestBanner : _iosProdBanner;
      default:
        return '';
    }
  }
}
