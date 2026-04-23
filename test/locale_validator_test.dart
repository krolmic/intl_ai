import 'package:intl_ai/src/locale_validator.dart';
import 'package:test/test.dart';

void main() {
  group('validate', () {
    test(
      'known simple locale is ${LocaleStatus.knownCldr.name} '
      '(case insensitive)',
      () {
        expect(
          LocaleValidator.validate('de'),
          equals(LocaleStatus.knownCldr),
        );
        expect(
          LocaleValidator.validate('DE'),
          equals(LocaleStatus.knownCldr),
        );
      },
    );

    test(
      'known locale with region is ${LocaleStatus.knownCldr.name} '
      '(separator insensitive)',
      () {
        expect(
          LocaleValidator.validate('de_DE'),
          equals(LocaleStatus.knownCldr),
        );
        expect(
          LocaleValidator.validate('de-DE'),
          equals(LocaleStatus.knownCldr),
        );
        expect(
          LocaleValidator.validate('DE-de'),
          equals(LocaleStatus.knownCldr),
        );
      },
    );

    test('known script variant is ${LocaleStatus.knownCldr.name}', () {
      expect(
        LocaleValidator.validate('zh_Hans'),
        equals(LocaleStatus.knownCldr),
      );
    });

    test('known lang-script-region is ${LocaleStatus.knownCldr.name}', () {
      expect(
        LocaleValidator.validate('sr_Latn_RS'),
        equals(LocaleStatus.knownCldr),
      );
    });

    test('nonsense locale is ${LocaleStatus.unknown.name}', () {
      expect(
        LocaleValidator.validate('xyz'),
        equals(LocaleStatus.unknown),
      );
      expect(
        LocaleValidator.validate('freanch'),
        equals(LocaleStatus.unknown),
      );
    });
  });
}
