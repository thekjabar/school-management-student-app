import 'package:flutter/cupertino.dart' show CupertinoLocalizations;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

const List<LocalizationsDelegate<dynamic>> appLocalizationsDelegates = [
  KurdishMaterialLocalizations(),
  KurdishWidgetsLocalizations(),
  KurdishCupertinoLocalizations(),
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

class KurdishMaterialLocalizations extends LocalizationsDelegate<MaterialLocalizations> {
  const KurdishMaterialLocalizations();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ku';

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      GlobalMaterialLocalizations.delegate.load(const Locale('ar'));

  @override
  bool shouldReload(KurdishMaterialLocalizations old) => false;
}

class KurdishWidgetsLocalizations extends LocalizationsDelegate<WidgetsLocalizations> {
  const KurdishWidgetsLocalizations();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ku';

  @override
  Future<WidgetsLocalizations> load(Locale locale) =>
      GlobalWidgetsLocalizations.delegate.load(const Locale('ar'));

  @override
  bool shouldReload(KurdishWidgetsLocalizations old) => false;
}

class KurdishCupertinoLocalizations extends LocalizationsDelegate<CupertinoLocalizations> {
  const KurdishCupertinoLocalizations();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ku';

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      GlobalCupertinoLocalizations.delegate.load(const Locale('ar'));

  @override
  bool shouldReload(KurdishCupertinoLocalizations old) => false;
}
