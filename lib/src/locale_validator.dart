import 'package:intl_ai/src/utils.dart';

enum LocaleStatus { knownCldr, unknown }

class LocaleValidator {
  static LocaleStatus validate(String locale) =>
      isKnownCldrLocale(locale) ? LocaleStatus.knownCldr : LocaleStatus.unknown;
}
