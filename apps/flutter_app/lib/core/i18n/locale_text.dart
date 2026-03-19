// Lightweight i18n helper for two-language UI copy.
import 'package:flutter/material.dart';

extension LocaleText on BuildContext {
  bool get isEnglish => Localizations.localeOf(this).languageCode == 'en';

  // Return Chinese or English copy based on current app locale.
  String tr(String zh, String en) {
    return isEnglish ? en : zh;
  }
}
