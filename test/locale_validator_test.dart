import 'package:intl_ai/src/locale_validator.dart';
import 'package:test/test.dart';

void main() {
  group('LocaleValidator.canonicalize', () {
    test('lowercases input', () {
      expect(LocaleValidator.canonicalize('DE'), equals('de'));
      expect(LocaleValidator.canonicalize('EN_US'), equals('en_us'));
    });

    test('replaces hyphens with underscores', () {
      expect(LocaleValidator.canonicalize('de-DE'), equals('de_de'));
      expect(LocaleValidator.canonicalize('sr-Latn-RS'), equals('sr_latn_rs'));
    });

    test('leaves already-canonical input unchanged', () {
      expect(LocaleValidator.canonicalize('zh_hans'), equals('zh_hans'));
    });
  });

  group('LocaleValidator.classify', () {
    test(
      'returns matchesExistingFile when fileExists regardless of locale',
      () {
        expect(
          LocaleValidator.classify(locale: 'xyz', fileExists: true),
          equals(LocaleStatus.matchesExistingFile),
        );
        expect(
          LocaleValidator.classify(locale: 'de', fileExists: true),
          equals(LocaleStatus.matchesExistingFile),
        );
      },
    );

    test('known simple locale is knownCldr (case insensitive)', () {
      expect(
        LocaleValidator.classify(locale: 'de', fileExists: false),
        equals(LocaleStatus.knownCldr),
      );
      expect(
        LocaleValidator.classify(locale: 'DE', fileExists: false),
        equals(LocaleStatus.knownCldr),
      );
    });

    test('known locale with region is knownCldr (separator insensitive)', () {
      expect(
        LocaleValidator.classify(locale: 'de_DE', fileExists: false),
        equals(LocaleStatus.knownCldr),
      );
      expect(
        LocaleValidator.classify(locale: 'de-DE', fileExists: false),
        equals(LocaleStatus.knownCldr),
      );
      expect(
        LocaleValidator.classify(locale: 'DE-de', fileExists: false),
        equals(LocaleStatus.knownCldr),
      );
    });

    test('known script variant is knownCldr', () {
      expect(
        LocaleValidator.classify(locale: 'zh_Hans', fileExists: false),
        equals(LocaleStatus.knownCldr),
      );
    });

    test('known lang-script-region is knownCldr', () {
      expect(
        LocaleValidator.classify(locale: 'sr_Latn_RS', fileExists: false),
        equals(LocaleStatus.knownCldr),
      );
    });

    test('nonsense locale with no existing file is unknown', () {
      expect(
        LocaleValidator.classify(locale: 'xyz', fileExists: false),
        equals(LocaleStatus.unknown),
      );
      expect(
        LocaleValidator.classify(locale: 'freanch', fileExists: false),
        equals(LocaleStatus.unknown),
      );
    });
  });
}
