import 'package:shared_preferences/shared_preferences.dart';

const String _keyOnboardingCompleted = 'onboarding_completed';

/// Persists whether the user has completed onboarding (first launch only).
class OnboardingStorage {
  static Future<bool> hasCompletedOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyOnboardingCompleted) ?? false;
  }

  static Future<void> setOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnboardingCompleted, true);
  }
}
