import 'dart:io';

import 'package:intl_ai/intl_ai.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('intl_ai_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  void writeYaml(String content) {
    File(p.join(tempDir.path, 'l10n.yaml')).writeAsStringSync(content);
  }

  group('L10nConfig.load', () {
    test('parses standard and ai_translation fields', () {
      writeYaml('''
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
ai_translation:
  provider: openai
  model: gpt-4.1-mini
  api_key_env: OPENAI_API_KEY
  ignore:
    - Deep Work
  context: Focus timer
''');

      final config = L10nConfig.load(tempDir.path);

      expect(config.arbDirectory, p.join(tempDir.path, 'lib/l10n'));
      expect(config.templateArbFile, 'app_en.arb');
      expect(config.outputLocalizationFile, 'app_localizations.dart');
      expect(config.aiTranslationConfig.provider, AiTranslationProvider.openai);
      expect(config.aiTranslationConfig.model, 'gpt-4.1-mini');
      expect(config.aiTranslationConfig.ignore, ['Deep Work']);
      expect(config.aiTranslationConfig.context, 'Focus timer');
    });

    test('templateLocale derived from template filename', () {
      writeYaml('''
template-arb-file: app_en.arb
ai_translation:
  provider: openai
  model: gpt-4
  api_key_env: KEY
''');

      final config = L10nConfig.load(tempDir.path);
      expect(config.templateLocale, 'en');
      expect(config.arbPrefix, 'app');
    });

    test('defaults arb-dir when not set', () {
      writeYaml('''
ai_translation:
  provider: anthropic
  model: claude-3-haiku-20240307
  api_key_env: KEY
''');

      final config = L10nConfig.load(tempDir.path);
      expect(config.arbDirectory, p.join(tempDir.path, 'lib/l10n'));
    });

    test('throws FileSystemException when l10n.yaml not found', () {
      expect(
        () => L10nConfig.load('/nonexistent/path'),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('throws FormatException when ai_translation section is missing', () {
      writeYaml('arb-dir: lib/l10n\n');
      expect(
        () => L10nConfig.load(tempDir.path),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
