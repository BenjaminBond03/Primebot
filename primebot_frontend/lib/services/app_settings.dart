import 'package:shared_preferences/shared_preferences.dart';

/// Small app-wide preference flags. Backed by SharedPreferences so it works
/// on every platform, including the web.
class AppSettings {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  static const _keyNotificationsEnabled = 'notifications_enabled';

  Future<bool> get notificationsEnabled async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyNotificationsEnabled) ?? true;
  }

  Future<void> setNotificationsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotificationsEnabled, value);
  }
}
