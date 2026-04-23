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
}
