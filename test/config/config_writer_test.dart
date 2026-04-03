import 'dart:io';

import 'package:intl_ai/src/config/ai_translation_config.dart';
import 'package:intl_ai/src/config/config_writer.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late String yamlPath;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('intl_ai_test_');
    yamlPath = p.join(tempDir.path, 'l10n.yaml');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  const fullConfig = AiTranslationConfig(
    provider: AiTranslationProvider.openai,
    model: 'gpt-4.1-mini',
    apiKeyEnv: 'OPENAI_API_KEY',
    doNotTranslatePhrases: ['Deep Work', 'Pomodoro'],
    context: 'Focus timer',
  );

  const minimalConfig = AiTranslationConfig(
    provider: AiTranslationProvider.anthropic,
    model: 'claude-sonnet-4-6',
    apiKeyEnv: 'ANTHROPIC_API_KEY',
  );

  group('ConfigWriter.writeAiTranslationSection', () {
    test('creates l10n.yaml from scratch with all fields', () {
      ConfigWriter.writeAiTranslationSection(yamlPath, fullConfig);

      final content = File(yamlPath).readAsStringSync();
      expect(content, contains('arb-dir: lib/l10n'));
      expect(content, contains('template-arb-file: app_en.arb'));
      expect(
        content,
        contains('output-localization-file: app_localizations.dart'),
      );
      expect(content, contains('ai_translation:'));
      expect(content, contains('  provider: openai'));
      expect(content, contains('  model: gpt-4.1-mini'));
      expect(content, contains('  api_key_env: OPENAI_API_KEY'));
      expect(content, contains('  do_not_translate_phrases:'));
      expect(content, contains('    - Deep Work'));
      expect(content, contains('    - Pomodoro'));
      expect(content, contains('  context: Focus timer'));
    });

    test('creates l10n.yaml with only required fields', () {
      ConfigWriter.writeAiTranslationSection(yamlPath, minimalConfig);

      final content = File(yamlPath).readAsStringSync();
      expect(content, contains('ai_translation:'));
      expect(content, contains('  provider: anthropic'));
      expect(content, contains('  model: claude-sonnet-4-6'));
      expect(content, contains('  api_key_env: ANTHROPIC_API_KEY'));
      expect(content, isNot(contains('do_not_translate_phrases')));
      expect(content, isNot(contains('context:')));
    });

    test('updates existing l10n.yaml that has ai_translation section', () {
      File(yamlPath).writeAsStringSync(
        'arb-dir: custom/l10n\n'
        'template-arb-file: messages_en.arb\n'
        'ai_translation:\n'
        '  provider: openai\n'
        '  model: gpt-4\n'
        '  api_key_env: OLD_KEY\n',
      );

      ConfigWriter.writeAiTranslationSection(yamlPath, minimalConfig);

      final content = File(yamlPath).readAsStringSync();
      expect(content, contains('arb-dir: custom/l10n'));
      expect(content, contains('template-arb-file: messages_en.arb'));
      expect(content, contains('  provider: anthropic'));
      expect(content, contains('  model: claude-sonnet-4-6'));
      expect(content, isNot(contains('gpt-4')));
      expect(content, isNot(contains('OLD_KEY')));
    });

    test('appends ai_translation to existing l10n.yaml without it', () {
      File(yamlPath).writeAsStringSync(
        'arb-dir: lib/l10n\n'
        'template-arb-file: app_en.arb\n',
      );

      ConfigWriter.writeAiTranslationSection(yamlPath, minimalConfig);

      final content = File(yamlPath).readAsStringSync();
      expect(content, contains('arb-dir: lib/l10n'));
      expect(content, contains('template-arb-file: app_en.arb'));
      expect(content, contains('ai_translation:'));
      expect(content, contains('  provider: anthropic'));
    });

    test('preserves content after ai_translation section', () {
      File(yamlPath).writeAsStringSync(
        'arb-dir: lib/l10n\n'
        'ai_translation:\n'
        '  provider: openai\n'
        '  model: gpt-4\n'
        '  api_key_env: KEY\n'
        'some-other-key: value\n',
      );

      ConfigWriter.writeAiTranslationSection(yamlPath, minimalConfig);

      final content = File(yamlPath).readAsStringSync();
      expect(content, contains('arb-dir: lib/l10n'));
      expect(content, contains('  provider: anthropic'));
      expect(content, contains('some-other-key: value'));
    });

    test('quotes values with special characters', () {
      const config = AiTranslationConfig(
        provider: AiTranslationProvider.openai,
        model: 'gpt-4.1-mini',
        apiKeyEnv: 'OPENAI_API_KEY',
        doNotTranslatePhrases: ['has: colon', 'has # hash'],
        context: 'context: with colon',
      );

      ConfigWriter.writeAiTranslationSection(yamlPath, config);

      final content = File(yamlPath).readAsStringSync();
      expect(content, contains('    - "has: colon"'));
      expect(content, contains('    - "has # hash"'));
      expect(content, contains('  context: "context: with colon"'));
    });
  });
}
