import 'package:intl_ai/src/cldr_locales.dart';
import 'package:intl_ai/src/utils.dart';

enum LocaleStatus { knownCldr, unknown }

class LocaleValidator {
  static LocaleStatus validate(String locale) {
    final canonical = canonicalizeLocale(locale);
    if (kKnownCldrLocales.contains(canonical)) return LocaleStatus.knownCldr;

    final parts = canonical.split('_');
    for (var i = parts.length - 1; i >= 1; i--) {
      final prefix = parts.sublist(0, i).join('_');
      if (kKnownCldrLocales.contains(prefix)) return LocaleStatus.knownCldr;
    }

    return LocaleStatus.unknown;
  }
}
