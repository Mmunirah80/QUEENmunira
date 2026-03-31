import 'package:shared_preferences/shared_preferences.dart';

const String _keyLoggedIn = 'auth_logged_in';

/// Persists login status for splash navigation (e.g. "go to Home if already logged in").
class AuthStorage {
  static Future<bool> isLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyLoggedIn) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setLoggedIn(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyLoggedIn, value);
    } catch (_) {}
  }
}
