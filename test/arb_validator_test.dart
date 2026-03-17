import 'package:intl_ai/src/arb_validator.dart';
import 'package:test/test.dart';

void main() {
  group('ArbValidator.extractPlaceholders', () {
    test('extracts simple placeholders', () {
      expect(
        ArbValidator.extractPlaceholders('Hello {name}!'),
        contains('name'),
      );
    });

    test('extracts multiple placeholders', () {
      final result = ArbValidator.extractPlaceholders(
        '{label} has {count} items',
      );
      expect(result, containsAll(['label', 'count']));
    });

    test('returns empty for no placeholders', () {
      expect(ArbValidator.extractPlaceholders('Hello world'), isEmpty);
    });
  });

  group('ArbValidator.validateIcuSyntax', () {
    test('returns null for balanced braces', () {
      expect(ArbValidator.validateIcuSyntax('Hello {name}'), isNull);
    });

    test('returns error for unclosed brace', () {
      expect(ArbValidator.validateIcuSyntax('Hello {name'), isNotNull);
    });

    test('returns error for extra closing brace', () {
      expect(ArbValidator.validateIcuSyntax('Hello name}'), isNotNull);
    });

    test('returns null for complex ICU', () {
      expect(
        ArbValidator.validateIcuSyntax(
          '{count, plural, =1{one item} other{{count} items}}',
        ),
        isNull,
      );
    });
  });

  group('ArbValidator.validateTranslation', () {
    test('passes valid translation with placeholder', () {
      final result = ArbValidator.validateTranslation(
        'Hello {name}!',
        'Hallo {name}!',
      );
      expect(result.isValid, isTrue);
    });

    test('fails when placeholder missing', () {
      final result = ArbValidator.validateTranslation(
        'Hello {name}!',
        'Hallo Welt!',
      );
      expect(result.isValid, isFalse);
      expect(result.error, contains('{name}'));
    });

    test('fails on unbalanced braces in translation', () {
      final result = ArbValidator.validateTranslation(
        'Hello {name}',
        'Hallo {name',
      );
      expect(result.isValid, isFalse);
    });

    test('passes when no placeholders in source', () {
      final result = ArbValidator.validateTranslation('Hello!', 'Hallo!');
      expect(result.isValid, isTrue);
    });
  });

  group('ArbValidator.sanitizePluralMessage', () {
    test('removes =1 when one is also present', () {
      const input =
          '{count, plural, =1{1 сессия} one{{count} сессия}'
          ' few{{count} сессии} other{{count} сессий}}';
      const expected =
          '{count, plural, one{{count} сессия}'
          ' few{{count} сессии} other{{count} сессий}}';
      expect(ArbValidator.removeRedundantPluralCategories(input), expected);
    });

    test('removes =0 when zero is also present', () {
      const input =
          '{count, plural, =0{no items} zero{nothing} other{{count} items}}';
      const expected = '{count, plural, zero{nothing} other{{count} items}}';
      expect(ArbValidator.removeRedundantPluralCategories(input), expected);
    });

    test('removes =2 when two is also present', () {
      const input =
          '{count, plural, =2{a pair} two{two items} other{{count} items}}';
      const expected = '{count, plural, two{two items} other{{count} items}}';
      expect(ArbValidator.removeRedundantPluralCategories(input), expected);
    });

    test('keeps =1 when one is not present', () {
      const input = '{count, plural, =1{1 item} other{{count} items}}';
      expect(ArbValidator.removeRedundantPluralCategories(input), input);
    });

    test('returns non-plural messages unchanged', () {
      const input = 'Hello {name}!';
      expect(ArbValidator.removeRedundantPluralCategories(input), input);
    });

    test('handles nested braces in plural content', () {
      const input =
          '{count, plural, =1{{count} item} one{{count} thing}'
          ' other{{count} items}}';
      const expected =
          '{count, plural, one{{count} thing} other{{count} items}}';
      expect(ArbValidator.removeRedundantPluralCategories(input), expected);
    });
  });
}
