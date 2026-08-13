import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider with ChangeNotifier {
  Locale _currentLocale = const Locale('en');

  Locale get currentLocale => _currentLocale;

  // Supported languages
  final List<Map<String, String>> supportedLanguages = [
    {'code': 'en', 'name': 'English', 'nativeName': 'English'},
    {'code': 'hi', 'name': 'Hindi', 'nativeName': 'हिन्दी'},
    {'code': 'mr', 'name': 'Marathi', 'nativeName': 'मराठी'},
  ];

  LanguageProvider() {
    _loadSavedLanguage();
  }

  // Load saved language from SharedPreferences
  Future<void> _loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString('language_code') ?? 'en';
    _currentLocale = Locale(languageCode);
    notifyListeners();
  }

  // Change language and save to SharedPreferences
  Future<void> changeLanguage(String languageCode) async {
    if (_currentLocale.languageCode == languageCode) return;

    _currentLocale = Locale(languageCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', languageCode);
    notifyListeners();
  }

  // Get language name by code
  String getLanguageName(String code) {
    final lang = supportedLanguages.firstWhere(
      (lang) => lang['code'] == code,
      orElse: () => {'name': 'English'},
    );
    return lang['name'] ?? 'English';
  }

  // Get native language name by code
  String getNativeLanguageName(String code) {
    final lang = supportedLanguages.firstWhere(
      (lang) => lang['code'] == code,
      orElse: () => {'nativeName': 'English'},
    );
    return lang['nativeName'] ?? 'English';
  }
}
