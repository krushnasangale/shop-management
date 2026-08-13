import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flashbill/theme/app_theme.dart';

class ThemeProvider with ChangeNotifier {
  static const _prefKey = 'is_light_theme';

  bool _isLightTheme = true;

  bool get isLightTheme => _isLightTheme;

  ThemeMode get themeMode =>
      _isLightTheme ? ThemeMode.light : ThemeMode.dark;

  ThemeData get lightTheme => AppTheme.light();

  ThemeData get darkTheme => AppTheme.dark();

  ThemeData get currentTheme => _isLightTheme ? lightTheme : darkTheme;

  ThemeProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getBool(_prefKey);
    if (stored != null && stored != _isLightTheme) {
      _isLightTheme = stored;
      notifyListeners();
    }
  }

  Future<void> toggleTheme() async {
    _isLightTheme = !_isLightTheme;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, _isLightTheme);
  }
}
