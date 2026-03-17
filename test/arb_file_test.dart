import 'dart:io';

import 'package:intl_ai/src/arb_file.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory testDirectory;

  setUp(() {
    testDirectory = Directory.systemTemp.createTempSync('intl_ai_arb_test_');
  });

  tearDown(() {
    testDirectory.deleteSync(recursive: true);
  });

  group('ArbFile.fromFile', () {
    test('parses entries and metadata correctly', () {
      final path = p.join(testDirectory.path, 'app_en.arb');
      File(path).writeAsStringSync('''
{
  "@@locale": "en",
  "appTitle": "Deep Work Timer",
  "@appTitle": {},
  "sessionCount": "{count, plural, =1{1 Session} other{{count} Sessions}}",
  "@sessionCount": {
    "placeholders": {
      "count": { "type": "int" }
    }
  }
}
''');

      final arb = ArbFile.fromFile(path);
      expect(arb.locale, 'en');
      expect(arb.entries['appTitle'], 'Deep Work Timer');
      expect(arb.entries.containsKey('@appTitle'), isFalse);
      expect(arb.metadata.containsKey('@sessionCount'), isTrue);
      expect(arb.entries.containsKey('@@locale'), isFalse);
    });

    test('throws FileSystemException for missing file', () {
      expect(
        () => ArbFile.fromFile('/nonexistent/file.arb'),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('throws FormatException for invalid JSON', () {
      final path = p.join(testDirectory.path, 'bad.arb');
      File(path).writeAsStringSync('not json');
      expect(
        () => ArbFile.fromFile(path),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('ArbFile.writeToFile', () {
    test('writes ARB with @@locale first and interleaved metadata', () {
      final path = p.join(testDirectory.path, 'app_de.arb');
      ArbFile(
        locale: 'de',
        entries: {'appTitle': 'Deep Work Timer'},
        metadata: {
          '@@locale': 'de',
          '@appTitle': {'description': 'App title'},
        },
      ).writeToFile(path);

      final content = File(path).readAsStringSync();
      expect(content, contains('"@@locale": "de"'));
      expect(content, contains('"appTitle": "Deep Work Timer"'));
      expect(content, contains('"@appTitle"'));

      // @@locale must come before the first entry
      final localeIndex = content.indexOf('@@locale');
      final titleIndex = content.indexOf('appTitle');
      expect(localeIndex, lessThan(titleIndex));
    });
  });

  group('ArbFile.getMissingKeys', () {
    test('returns keys in template not in target', () {
      final template = getTestArbFile({'a': '1', 'b': '2', 'c': '3'});
      final target = getTestArbFile({'a': 'uno'});

      expect(template.getMissingKeys(target), containsAll(['b', 'c']));
      expect(template.getMissingKeys(target), isNot(contains('a')));
    });

    test('returns empty when target has all template keys', () {
      final template = getTestArbFile({'a': '1'});
      final target = getTestArbFile({'a': 'uno', 'b': 'dos'});

      expect(template.getMissingKeys(target), isEmpty);
    });
  });

  group('ArbFile.allKeys', () {
    test('returns all entry keys', () {
      final template = getTestArbFile({'a': '1', 'b': '2'});
      expect(template.allKeys, containsAll(['a', 'b']));
    });

    test('returns empty list for empty template', () {
      expect(getTestArbFile({}).allKeys, isEmpty);
    });
  });
}

ArbFile getTestArbFile(Map<String, String> entries) =>
    ArbFile(locale: 'test', entries: entries, metadata: {});
