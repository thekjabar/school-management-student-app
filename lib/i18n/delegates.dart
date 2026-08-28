import 'package:flutter/cupertino.dart' show CupertinoLocalizations;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/* ---------------------------------------------------------------------------
 * Kurdish framework strings
 *
 * Flutter ships translations for 78 locales and Kurdish is not among them. The
 * app's own text comes from lib/i18n/strings.dart, but the framework's does
 * not — the date picker's month names, a text field's "Paste", the Material
 * "OK" and "Cancel" — and without a delegate that admits to supporting 'ku'
 * every one of those widgets throws on build. That was the crash on switching
 * to Kurdish.
 *
 * Arabic is the substitute: right-to-left, widely read in the Region, and
 * already complete. A Kurdish speaker sees Kurdish everywhere the app writes
 * the words itself, and Arabic in the few places the framework does.
 *
 * This lives outside main.dart so the widget tests can mount the very same
 * list the app ships. A test that builds its own shorter list proves nothing
 * about the app.
 * ------------------------------------------------------------------------- */

/// The app's localisation delegates, in the order that matters.
///
/// The Kurdish three come first: delegates are matched front to back, so these
/// get the chance to claim 'ku' before the global ones decline it.
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
