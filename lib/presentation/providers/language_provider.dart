import 'package:flutter/foundation.dart';
import 'package:high_school/core/constants/app_constants.dart';
import 'package:high_school/core/l10n/app_translations.dart' as l10n;
import 'package:high_school/core/l10n/auth_error_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider with ChangeNotifier {
  LanguageProvider(this._prefs) {
    final code = _prefs.getString(AppConstants.languageKey) ?? 'en';
    _lang = l10n.AppLanguage.values.firstWhere(
      (e) => e.code == code,
      orElse: () => l10n.AppLanguage.en,
    );
  }

  final SharedPreferences _prefs;
  late l10n.AppLanguage _lang;

  l10n.AppLanguage get language => _lang;

  String t(String key) => l10n.t(_lang, key);

  /// Turns known English API / validation messages into the active locale.
  String localizeAuthMessage(String message) => localizedAuthApiMessage(_lang, message);

  Future<void> setLanguage(l10n.AppLanguage lang) async {
    if (_lang == lang) return;
    _lang = lang;
    notifyListeners();
    await _prefs.setString(AppConstants.languageKey, lang.code);
  }
}
