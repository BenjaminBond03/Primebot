import 'package:flutter/foundation.dart' show kIsWeb;

// Production/deployed backend URL, injected at build time so a release APK
// can point at Railway without touching this file:
//   flutter build apk --release --dart-define=API_BASE_URL=https://<app>.up.railway.app
// Local `flutter run` builds get an empty string here and fall through to
// the dev URLs below, so day-to-day local development is unaffected.
const String _deployedUrl = String.fromEnvironment('API_BASE_URL');

// Chrome/web runs on this same dev machine, so it must use localhost - the
// LAN IP below is only for a physical phone on the same Wi-Fi network as
// this machine (update it if that IP changes: `ipconfig` -> Wireless LAN
// adapter Wi-Fi -> IPv4 Address). The Android emulator alias (10.0.2.2) is
// intentionally not handled here since emulator testing is currently paused.
const String _lanUrl = 'http://172.20.10.4:8000';
const String _localhostUrl = 'http://localhost:8000';

String get apiBaseUrl {
  if (_deployedUrl.isNotEmpty) return _deployedUrl;
  return kIsWeb ? _localhostUrl : _lanUrl;
}
