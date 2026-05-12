import 'package:intl_ai/src/utils.dart';
import 'package:test/test.dart';

void main() {
  group('canonicalizeLocale', () {
    test('lowercases input', () {
      expect(canonicalizeLocale('DE'), equals('de'));
      expect(canonicalizeLocale('EN_US'), equals('en_us'));
    });

    test('replaces hyphens with underscores', () {
      expect(canonicalizeLocale('de-DE'), equals('de_de'));
      expect(canonicalizeLocale('sr-Latn-RS'), equals('sr_latn_rs'));
    });

    test('leaves already-canonical input unchanged', () {
      expect(canonicalizeLocale('zh_hans'), equals('zh_hans'));
    });
  });

  group('parseLocaleFromFilename', () {
    void expectParse(
      String filename, {
      required String prefix,
      required String locale,
    }) {
      final result = parseLocaleFromFilename(filename);
      expect(
        result.prefix,
        equals(prefix),
        reason: 'prefix for $filename',
      );
      expect(
        result.locale,
        equals(locale),
        reason: 'locale for $filename',
      );
    }

    test('simple language', () {
      expectParse('app_en.arb', prefix: 'app', locale: 'en');
    });

    test('country code', () {
      expectParse('app_en_US.arb', prefix: 'app', locale: 'en_US');
      expectParse('app_pt_BR.arb', prefix: 'app', locale: 'pt_BR');
    });

    test('numeric region', () {
      expectParse('app_es_419.arb', prefix: 'app', locale: 'es_419');
    });

    test('script', () {
      expectParse('app_zh_Hans.arb', prefix: 'app', locale: 'zh_Hans');
    });

    test('full compound', () {
      expectParse(
        'app_zh_Hans_CN.arb',
        prefix: 'app',
        locale: 'zh_Hans_CN',
      );
    });

    test('hyphen inside a segment resolves via canonicalization', () {
      expectParse('app_zh-Hans.arb', prefix: 'app', locale: 'zh-Hans');
    });

    test('multi-word prefix', () {
      expectParse(
        'intl_messages_en.arb',
        prefix: 'intl_messages',
        locale: 'en',
      );
    });

    test('no prefix', () {
      expectParse('en.arb', prefix: '', locale: 'en');
      expectParse('zh_Hans.arb', prefix: '', locale: 'zh_Hans');
    });

    test('unknown locale falls back to last segment', () {
      expectParse('app_xyz.arb', prefix: 'app', locale: 'xyz');
    });

    test('no underscore falls back to whole name', () {
      expectParse('messages.arb', prefix: '', locale: 'messages');
    });

    test('preserves original casing', () {
      expectParse('app_zh_Hans.arb', prefix: 'app', locale: 'zh_Hans');
      expectParse('app_pt_BR.arb', prefix: 'app', locale: 'pt_BR');
      expectParse(
        'app_sr_Latn_RS.arb',
        prefix: 'app',
        locale: 'sr_Latn_RS',
      );
    });

    test('strips file extension', () {
      expectParse('app_en', prefix: 'app', locale: 'en');
      expectParse('app_en.arb', prefix: 'app', locale: 'en');
    });
  });
}
