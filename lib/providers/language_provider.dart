import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages language selection: English, Tagalog, or Partial Tagalog.
class LanguageProvider extends ChangeNotifier {
  String _code = 'en';
  String get languageCode => _code;
  Locale get locale => Locale(_code);

  static const _key = 'language_code';

  LanguageProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _code = prefs.getString(_key) ?? 'en';
    notifyListeners();
  }

  Future<void> setLanguage(String code) async {
    if (code == _code) return;
    _code = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, code);
    notifyListeners();
  }

  String get languageName {
    switch (_code) {
      case 'tl':
        return 'Tagalog';
      case 'tl_partial':
        return 'Partial Tagalog';
      default:
        return 'English';
    }
  }
}
