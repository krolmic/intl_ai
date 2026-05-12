import 'package:intl_ai/src/arb_validator.dart';
import 'package:logging/logging.dart';
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

    test('ignores tokens inside ICU plural branches', () {
      // 'x' and 'y' are raw branch text, not placeholders — they must not
      // be returned. Arg-name preservation (validation #2) covers ICU names.
      expect(
        ArbValidator.extractPlaceholders(
          '{count, plural, one{x} other{y}}',
        ),
        isEmpty,
      );
    });

    test(
      'still catches placeholders outside ICU blocks in the same string',
      () {
        expect(
          ArbValidator.extractPlaceholders(
            '{name} ate {count, plural, one{x} other{y}}',
          ),
          equals(['name']),
        );
      },
    );
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

  group('ArbValidator.validateTranslation – mandatory other branch', () {
    test('passes when flat plural has other', () {
      const message = '{count, plural, one{x} other{y}}';
      final result = ArbValidator.validateTranslation(message, message);
      expect(result.isValid, isTrue);
    });

    test('fails when flat plural is missing other', () {
      const source = '{count, plural, one{x} other{y}}';
      const translated = '{count, plural, one{x}}';
      final result = ArbValidator.validateTranslation(source, translated);
      expect(result.isValid, isFalse);
      expect(
        result.error,
        equals("missing 'other' branch in plural argument 'count'"),
      );
    });

    test('passes when nested plural has other', () {
      const message =
          '{gender, select, male{x} female{x} '
          'other{{count, plural, one{a} other{b}}}}';
      final result = ArbValidator.validateTranslation(message, message);
      expect(result.isValid, isTrue);
    });

    test('fails when nested plural is missing other', () {
      const source =
          '{gender, select, male{x} female{x} '
          'other{{count, plural, one{a} other{b}}}}';
      const translated =
          '{gender, select, male{x} female{x} '
          'other{{count, plural, one{a}}}}';
      final result = ArbValidator.validateTranslation(source, translated);
      expect(result.isValid, isFalse);
      expect(
        result.error,
        equals("missing 'other' branch in plural argument 'count'"),
      );
    });

    test('fails when select is missing other', () {
      const source = '{role, select, admin{x} other{y}}';
      const translated = '{role, select, admin{x} user{y}}';
      final result = ArbValidator.validateTranslation(source, translated);
      expect(result.isValid, isFalse);
      expect(
        result.error,
        equals("missing 'other' branch in select argument 'role'"),
      );
    });
  });

  group('ArbValidator.validateTranslation – arg-name preservation', () {
    test('passes when names match', () {
      const source = '{count, plural, one{x} other{y}}';
      const translated = '{count, plural, one{a} other{b}}';
      final result = ArbValidator.validateTranslation(source, translated);
      expect(result.isValid, isTrue);
    });

    test('fails when arg name is renamed', () {
      const source = '{count, plural, one{x} other{y}}';
      const translated = '{cantidad, plural, one{a} other{b}}';
      final result = ArbValidator.validateTranslation(source, translated);
      expect(result.isValid, isFalse);
      expect(
        result.error,
        equals("ICU argument 'count' missing in translation"),
      );
    });

    test('passes when nested arg names match', () {
      const source =
          '{role, select, admin{x} '
          'other{{count, plural, one{a} other{b}}}}';
      const translated =
          '{role, select, admin{y} '
          'other{{count, plural, one{c} other{d}}}}';
      final result = ArbValidator.validateTranslation(source, translated);
      expect(result.isValid, isTrue);
    });

    test('fails when nested arg name is renamed', () {
      const source =
          '{role, select, admin{x} '
          'other{{count, plural, one{a} other{b}}}}';
      const translated =
          '{role, select, admin{y} '
          'other{{cantidad, plural, one{c} other{d}}}}';
      final result = ArbValidator.validateTranslation(source, translated);
      expect(result.isValid, isFalse);
      expect(
        result.error,
        equals("ICU argument 'count' missing in translation"),
      );
    });
  });

  group('ArbValidator.validateTranslation – plural categories', () {
    test('passes when keywords are valid for fr', () {
      const message = '{count, plural, one{x} many{y} other{z}}';
      final result = ArbValidator.validateTranslation(
        message,
        message,
        targetLocale: 'fr',
      );
      expect(result.isValid, isTrue);
    });

    test('fails when fr translation uses few', () {
      const source = '{count, plural, one{x} other{y}}';
      const translated = '{count, plural, few{x} other{y}}';
      final result = ArbValidator.validateTranslation(
        source,
        translated,
        targetLocale: 'fr',
      );
      expect(result.isValid, isFalse);
      expect(
        result.error,
        equals(
          "invalid plural category 'few' for locale 'fr' "
          '(allowed: one, many, other)',
        ),
      );
    });

    test('fails when keyword is mis-cased', () {
      const source = '{count, plural, one{x} other{y}}';
      const translated = '{count, plural, One{x} other{y}}';
      final result = ArbValidator.validateTranslation(
        source,
        translated,
        targetLocale: 'en',
      );
      expect(result.isValid, isFalse);
      expect(
        result.error,
        equals(
          "invalid plural category 'One' for locale 'en' "
          '(allowed: one, other)',
        ),
      );
    });

    test('skips check when targetLocale is null', () {
      const source = '{count, plural, one{x} other{y}}';
      const translated = '{count, plural, few{x} other{y}}';
      final result = ArbValidator.validateTranslation(source, translated);
      expect(result.isValid, isTrue);
    });

    test('skips check when targetLocale is unmapped', () {
      const source = '{count, plural, one{x} other{y}}';
      const translated = '{count, plural, few{x} other{y}}';
      final result = ArbValidator.validateTranslation(
        source,
        translated,
        targetLocale: 'qzz',
      );
      expect(result.isValid, isTrue);
    });

    test(
      'resolves pt_BR via language-subtag (no fallback needed: direct hit)',
      () {
        const source = '{count, plural, one{x} other{y}}';
        const translated = '{count, plural, one{a} other{b}}';
        final result = ArbValidator.validateTranslation(
          source,
          translated,
          targetLocale: 'pt_BR',
        );
        expect(result.isValid, isTrue);
      },
    );

    test('falls back to language subtag for unknown region', () {
      // pt_AO is not in intl's registry; falls back to pt.
      const source = '{count, plural, one{x} other{y}}';
      const translated = '{count, plural, few{x} other{y}}';
      final result = ArbValidator.validateTranslation(
        source,
        translated,
        targetLocale: 'pt_AO',
      );
      expect(result.isValid, isFalse);
      expect(result.error, contains("for locale 'pt_AO'"));
    });

    test(
      '=N selectors exempt; survives removeRedundantPluralCategories strip',
      () {
        // The translator calls removeRedundantPluralCategories before
        // validateTranslation, which strips =1 when 'one' is also present.
        // Run that pipeline here to lock in: =0 stays (no 'zero'), 'one' and
        // 'other' are valid for fr, the stripped =1 is never seen by #3.
        const raw = '{count, plural, =0{a} =1{b} one{c} other{d}}';
        final stripped = ArbValidator.removeRedundantPluralCategories(raw);
        expect(stripped, isNot(contains('=1')));
        final result = ArbValidator.validateTranslation(
          raw,
          stripped,
          targetLocale: 'fr',
        );
        expect(result.isValid, isTrue);
      },
    );

    test('logs Level.FINE once on first miss per locale', () async {
      ArbValidator.resetPluralCategoryCache();
      final originalLevel = Logger.root.level;
      Logger.root.level = Level.ALL;
      final logs = <LogRecord>[];
      final sub = Logger('IntlAi.ArbValidator').onRecord.listen(logs.add);

      ArbValidator.getPluralCategoriesForLocale('qzz');
      ArbValidator.getPluralCategoriesForLocale('qzz');

      await sub.cancel();
      Logger.root.level = originalLevel;

      final fineLogs = logs
          .where(
            (r) => r.level == Level.FINE && r.message.contains("'qzz'"),
          )
          .toList();
      expect(fineLogs, hasLength(1));
    });
  });

  group('ArbValidator.validateTranslation – ICU quoting', () {
    test("quoted braces don't open an arg block", () {
      const source = "Use '{notArg}' literally.";
      const translated = "Utilisez '{notArg}' littéralement.";
      final result = ArbValidator.validateTranslation(source, translated);
      expect(result.isValid, isTrue);
    });

    test('double apostrophe inside a real plural still validates', () {
      const message = "it''s {count, plural, one{x} other{y}}";
      final result = ArbValidator.validateTranslation(message, message);
      expect(result.isValid, isTrue);
    });
  });

  group('ArbValidator.validateTranslation – short-circuit order', () {
    test('returns arg-name error when both arg-name and other-branch fail', () {
      const source = '{count, plural, one{x} other{y}}';
      const translated = '{cantidad, plural, one{a}}';
      final result = ArbValidator.validateTranslation(source, translated);
      expect(result.isValid, isFalse);
      expect(
        result.error,
        equals("ICU argument 'count' missing in translation"),
      );
    });

    test('empty translation fails at simple-placeholder step', () {
      const source = 'Hello {name}!';
      const translated = '';
      final result = ArbValidator.validateTranslation(source, translated);
      expect(result.isValid, isFalse);
      expect(result.error, equals('missing placeholder: {name}'));
    });
  });

  group('ArbValidator.getPluralCategoriesForLocale', () {
    test('resolves en to {one, other}', () {
      expect(
        ArbValidator.getPluralCategoriesForLocale('en'),
        equals({'one', 'other'}),
      );
    });

    test('resolves fr to {one, many, other}', () {
      expect(
        ArbValidator.getPluralCategoriesForLocale('fr'),
        equals({'one', 'many', 'other'}),
      );
    });

    test('resolves ar to {zero, one, two, few, many, other}', () {
      expect(
        ArbValidator.getPluralCategoriesForLocale('ar'),
        equals({'zero', 'one', 'two', 'few', 'many', 'other'}),
      );
    });

    test('resolves ja to {other}', () {
      expect(
        ArbValidator.getPluralCategoriesForLocale('ja'),
        equals({'other'}),
      );
    });

    test('resolves pl to {one, few, many, other}', () {
      expect(
        ArbValidator.getPluralCategoriesForLocale('pl'),
        equals({'one', 'few', 'many', 'other'}),
      );
    });

    test('returns null for unmapped locale', () {
      expect(ArbValidator.getPluralCategoriesForLocale('qzz'), isNull);
    });

    test('resolves pt_br via case-insensitive registry lookup', () {
      expect(
        ArbValidator.getPluralCategoriesForLocale('pt_br'),
        equals({'one', 'many', 'other'}),
      );
    });

    test('repeat calls return the same cached Set instance', () {
      final first = ArbValidator.getPluralCategoriesForLocale('de');
      final second = ArbValidator.getPluralCategoriesForLocale('de');
      expect(identical(first, second), isTrue);
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
