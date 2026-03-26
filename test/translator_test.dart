import 'dart:io';

import 'package:intl_ai/src/config/ai_translation_config.dart';
import 'package:intl_ai/src/config/l10n_config.dart';
import 'package:intl_ai/src/intl_ai_exception.dart';
import 'package:intl_ai/src/repositories/translation_repository.dart';
import 'package:intl_ai/src/translator.dart';
import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

class MockTranslationRepository extends Mock implements TranslationRepository {}

class FakeAiTranslationConfig extends Fake implements AiTranslationConfig {}

void main() {
  late Directory tempDir;
  late Directory arbDir;
  late MockTranslationRepository mockRepository;
  late L10nConfig config;

  setUpAll(() {
    registerFallbackValue(FakeAiTranslationConfig());
  });

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('intl_ai_translator_test_');
    arbDir = Directory(p.join(tempDir.path, 'lib', 'l10n'))
      ..createSync(recursive: true);
    mockRepository = MockTranslationRepository();

    File(p.join(tempDir.path, 'l10n.yaml')).writeAsStringSync('''
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
ai_translation:
  provider: openai
  model: gpt-4.1-mini
  api_key_env: TEST_KEY
''');

    File(p.join(arbDir.path, 'app_en.arb')).writeAsStringSync('''
{
  "@@locale": "en",
  "appTitle": "Deep Work Timer",
  "cancel": "Cancel"
}
''');

    File(p.join(arbDir.path, 'app_de.arb')).writeAsStringSync('''
{
  "@@locale": "de",
  "appTitle": "Deep Work Timer"
}
''');

    config = L10nConfig.load(tempDir.path);
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  group('Translator.translateLocales', () {
    test('incremental mode translates only missing keys', () async {
      when(
        () => mockRepository.getTranslations(
          keys: {'cancel': 'Cancel'},
          sourceLocale: 'en',
          targetLocale: 'de',
          config: any(named: 'config'),
        ),
      ).thenAnswer((_) async => {'cancel': 'Abbrechen'});

      final translator = Translator(
        config: config,
        projectRoot: tempDir.path,
        repository: mockRepository,
      );

      await translator.translateLocales();

      verify(
        () => mockRepository.getTranslations(
          keys: {'cancel': 'Cancel'},
          sourceLocale: 'en',
          targetLocale: 'de',
          config: any(named: 'config'),
        ),
      ).called(1);

      final deContent = File(
        p.join(arbDir.path, 'app_de.arb'),
      ).readAsStringSync();
      expect(deContent, contains('Abbrechen'));
      expect(deContent, contains('Deep Work Timer'));
    });

    test('full mode translates all keys', () async {
      when(
        () => mockRepository.getTranslations(
          keys: {'appTitle': 'Deep Work Timer', 'cancel': 'Cancel'},
          sourceLocale: 'en',
          targetLocale: 'de',
          config: any(named: 'config'),
        ),
      ).thenAnswer(
        (_) async => {'appTitle': 'Deep Work Timer', 'cancel': 'Abbrechen'},
      );

      final translator = Translator(
        config: config,
        projectRoot: tempDir.path,
        repository: mockRepository,
      );

      await translator.translateLocales(retranslateAll: true);

      verify(
        () => mockRepository.getTranslations(
          keys: {'appTitle': 'Deep Work Timer', 'cancel': 'Cancel'},
          sourceLocale: 'en',
          targetLocale: 'de',
          config: any(named: 'config'),
        ),
      ).called(1);
    });

    test('dry-run mode does not write ARB files', () async {
      when(
        () => mockRepository.getTranslations(
          keys: any(named: 'keys'),
          sourceLocale: any(named: 'sourceLocale'),
          targetLocale: any(named: 'targetLocale'),
          config: any(named: 'config'),
        ),
      ).thenAnswer((_) async => {'cancel': 'Abbrechen'});

      final translator = Translator(
        config: config,
        projectRoot: tempDir.path,
        repository: mockRepository,
      );

      final beforeContent = File(
        p.join(arbDir.path, 'app_de.arb'),
      ).readAsStringSync();

      await translator.translateLocales(dryRunIsEnabled: true);

      final afterContent = File(
        p.join(arbDir.path, 'app_de.arb'),
      ).readAsStringSync();

      expect(afterContent, equals(beforeContent));

      expect(
        File(p.join(arbDir.path, '.intl_ai_dry_run.json')).existsSync(),
        isTrue,
      );
    });

    test('locale flag translates only specified locale', () async {
      File(p.join(arbDir.path, 'app_fr.arb')).writeAsStringSync('''
{
  "@@locale": "fr",
  "appTitle": "Deep Work Timer"
}
''');

      when(
        () => mockRepository.getTranslations(
          keys: {'cancel': 'Cancel'},
          sourceLocale: 'en',
          targetLocale: 'de',
          config: any(named: 'config'),
        ),
      ).thenAnswer((_) async => {'cancel': 'Abbrechen'});

      final translator = Translator(
        config: config,
        projectRoot: tempDir.path,
        repository: mockRepository,
      );

      await translator.translateLocales(targetLocale: 'de');

      verify(
        () => mockRepository.getTranslations(
          keys: any(named: 'keys'),
          sourceLocale: 'en',
          targetLocale: 'de',
          config: any(named: 'config'),
        ),
      ).called(1);

      verifyNever(
        () => mockRepository.getTranslations(
          keys: any(named: 'keys'),
          sourceLocale: 'en',
          targetLocale: 'fr',
          config: any(named: 'config'),
        ),
      );
    });
  });

  group('Translator key validation', () {
    test('logs warning when keys are missing from AI response', () async {
      File(p.join(arbDir.path, 'app_de.arb')).writeAsStringSync('''
{
  "@@locale": "de"
}
''');

      when(
        () => mockRepository.getTranslations(
          keys: any(named: 'keys'),
          sourceLocale: 'en',
          targetLocale: 'de',
          config: any(named: 'config'),
        ),
      ).thenAnswer((_) async => {});

      final logs = <LogRecord>[];
      final sub = Logger('IntlAi.Translator').onRecord.listen(logs.add);

      final translator = Translator(
        config: config,
        projectRoot: tempDir.path,
        repository: mockRepository,
      );

      await translator.translateLocales(retranslateAll: true);
      await sub.cancel();

      verify(
        () => mockRepository.getTranslations(
          keys: any(named: 'keys'),
          sourceLocale: 'en',
          targetLocale: 'de',
          config: any(named: 'config'),
        ),
      ).called(1);

      expect(
        logs.any(
          (r) =>
              r.level == Level.WARNING &&
              r.message.contains('key(s) missing from AI response'),
        ),
        isTrue,
      );
    });
  });

  group('TranslationRepository.getSystemPrompt', () {
    test('requires all keys in output', () {
      final prompt = TranslationRepository.getSystemPrompt(
        sourceLocale: 'en',
        targetLocale: 'de',
        ignoreTerms: [],
      );
      expect(
        prompt,
        contains('Every key from the input MUST appear in the output'),
      );
    });
  });

  group('Translator.applyDryRun', () {
    test('applies dry-run file to ARB files', () async {
      File(p.join(arbDir.path, '.intl_ai_dry_run.json')).writeAsStringSync('''
{
  "generated_at": "2026-01-01T00:00:00Z",
  "provider": "openai",
  "model": "gpt-4.1-mini",
  "template_locale": "en",
  "translations": {
    "de": {
      "cancel": "Abbrechen"
    }
  }
}
''');

      final translator = Translator(
        config: config,
        projectRoot: tempDir.path,
        repository: mockRepository,
      );

      await translator.applyDryRun();

      final deContent = File(
        p.join(arbDir.path, 'app_de.arb'),
      ).readAsStringSync();
      expect(deContent, contains('Abbrechen'));
    });

    test('throws StateError when no dry-run file exists', () async {
      final translator = Translator(
        config: config,
        projectRoot: tempDir.path,
        repository: mockRepository,
      );

      expect(translator.applyDryRun, throwsA(isA<IntlAiException>()));
    });
  });
}
