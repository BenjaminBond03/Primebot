import 'package:shared_preferences/shared_preferences.dart';

/// Caches the logged-in user's profile locally so the app can display it
/// without another network round-trip. Backed by SharedPreferences (not
/// sqflite) specifically because this needs to work on every platform,
/// including the web, where sqflite has no browser storage backend.
class UserSession {
  UserSession._();
  static final UserSession instance = UserSession._();

  static const _keyId = 'session_user_id';
  static const _keyUsername = 'session_username';
  static const _keyEmail = 'session_email';

  Future<void> save({required int id, required String username, required String email}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyId, id);
    await prefs.setString(_keyUsername, username);
    await prefs.setString(_keyEmail, email);
  }

  Future<Map<String, Object>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt(_keyId);
    final username = prefs.getString(_keyUsername);
    final email = prefs.getString(_keyEmail);
    if (id == null || username == null || email == null) return null;
    return {'id': id, 'username': username, 'email': email};
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyId);
    await prefs.remove(_keyUsername);
    await prefs.remove(_keyEmail);
  }
}
