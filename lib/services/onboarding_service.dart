import 'package:shared_preferences/shared_preferences.dart';

class OnboardingService {
  static const _completedKey = 'onboarding_completed';
  static const _notificationPromptKey = 'onboarding_notification_prompted';

  static Future<bool> hasCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_completedKey) ?? false;
  }

  static Future<void> complete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_completedKey, true);
  }

  static Future<bool> wasNotificationPrompted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationPromptKey) ?? false;
  }

  static Future<void> markNotificationPrompted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationPromptKey, true);
  }
}
