import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'app_localizations.dart';

/// Localization delegate for SariBay POS.
class SariBayLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  final String languageCode;
  const SariBayLocalizationsDelegate({this.languageCode = 'en'});

  @override
  bool isSupported(Locale locale) => ['en', 'tl', 'tl_partial'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale.languageCode);
  }

  @override
  bool shouldReload(SariBayLocalizationsDelegate old) => old.languageCode != languageCode;
}

/// Helper to get localizations from context.
AppLocalizations loc(BuildContext context) => AppLocalizations.of(context);
