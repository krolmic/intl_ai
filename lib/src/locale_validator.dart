import 'package:intl_ai/src/cldr_locales.dart';

enum LocaleStatus { matchesExistingFile, knownCldr, unknown }

class LocaleValidator {
  static String canonicalize(String locale) =>
      locale.replaceAll('-', '_').toLowerCase();

  static LocaleStatus classify({
    required String locale,
    required bool fileExists,
  }) {
    if (fileExists) return LocaleStatus.matchesExistingFile;
    final canonical = canonicalize(locale);
    if (kKnownCldrLocales.contains(canonical)) return LocaleStatus.knownCldr;

    final parts = canonical.split('_');
    for (var i = parts.length - 1; i >= 1; i--) {
      final prefix = parts.sublist(0, i).join('_');
      if (kKnownCldrLocales.contains(prefix)) return LocaleStatus.knownCldr;
    }

    return LocaleStatus.unknown;
  }
}
