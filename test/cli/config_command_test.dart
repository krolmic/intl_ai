import 'dart:io';

import 'package:intl_ai/src/cli/config_command.dart';
import 'package:intl_ai/src/config/model_options.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

class _MockLogger extends Mock implements Logger {}

void main() {
  late _MockLogger logger;
  late Directory tempDir;
  late Directory originalDir;

  setUp(() {
    logger = _MockLogger();
    tempDir = Directory.systemTemp.createTempSync('intl_ai_config_test_');
    originalDir = Directory.current;
    Directory.current = tempDir;
  });

  tearDown(() {
    Directory.current = originalDir;
    tempDir.deleteSync(recursive: true);
  });

  void stubFullFlow({
    String provider = 'openai',
    String model = 'gpt-4.1-mini',
    String apiKeyEnv = 'OPENAI_API_KEY',
    String phrasesAction = 'Done',
    String context = '',
  }) {
    when(
      () => logger.chooseOne(
        'Select provider:',
        choices: any<List<String>>(named: 'choices'),
        defaultValue: any<String>(named: 'defaultValue'),
      ),
    ).thenReturn(provider);

    when(
      () => logger.chooseOne(
        'Select model:',
        choices: any<List<String>>(named: 'choices'),
        defaultValue: any<String>(named: 'defaultValue'),
      ),
    ).thenReturn(model);

    when(
      () => logger.prompt(
        'API key environment variable:',
        defaultValue: any<String>(named: 'defaultValue'),
      ),
    ).thenReturn(apiKeyEnv);

    when(
      () => logger.chooseOne(
        'Do not translate phrases:',
        choices: any<List<String>>(named: 'choices'),
        defaultValue: any<String>(named: 'defaultValue'),
      ),
    ).thenReturn(phrasesAction);

    when(
      () => logger.prompt(
        'App context (optional):',
        defaultValue: any<String>(named: 'defaultValue'),
      ),
    ).thenReturn(context);

    when(() => logger.success(any())).thenReturn(null);
    when(() => logger.info(any())).thenReturn(null);
  }

  group('ConfigCommand', () {
    test('creates new l10n.yaml with openai config', () async {
      stubFullFlow();

      final command = ConfigCommand(logger: logger);
      final exitCode = await command.run();

      expect(exitCode, 0);

      final yamlPath = p.join(tempDir.path, 'l10n.yaml');
      final content = File(yamlPath).readAsStringSync();
      expect(content, contains('arb-dir: lib/l10n'));
      expect(content, contains('provider: openai'));
      expect(content, contains('model: gpt-4.1-mini'));
      expect(content, contains('api_key_env: OPENAI_API_KEY'));

      verify(() => logger.success(any())).called(1);
    });

    test('creates config with anthropic provider', () async {
      stubFullFlow(
        provider: 'anthropic',
        model: 'claude-sonnet-4-6',
        apiKeyEnv: 'ANTHROPIC_API_KEY',
      );

      final command = ConfigCommand(logger: logger);
      final exitCode = await command.run();

      expect(exitCode, 0);

      final content = File(
        p.join(tempDir.path, 'l10n.yaml'),
      ).readAsStringSync();
      expect(content, contains('provider: anthropic'));
      expect(content, contains('model: claude-sonnet-4-6'));
      expect(content, contains('api_key_env: ANTHROPIC_API_KEY'));
    });

    test('creates config with context', () async {
      stubFullFlow(context: 'Focus timer');

      final command = ConfigCommand(logger: logger);
      await command.run();

      final content = File(
        p.join(tempDir.path, 'l10n.yaml'),
      ).readAsStringSync();
      expect(content, contains('context: Focus timer'));
    });

    test('handles Other model option with manual entry', () async {
      when(
        () => logger.chooseOne(
          'Select provider:',
          choices: any<List<String>>(named: 'choices'),
          defaultValue: any<String>(named: 'defaultValue'),
        ),
      ).thenReturn('openai');

      when(
        () => logger.chooseOne(
          'Select model:',
          choices: any<List<String>>(named: 'choices'),
          defaultValue: any<String>(named: 'defaultValue'),
        ),
      ).thenReturn(otherModelOption);

      when(() => logger.prompt('Enter model name:')).thenReturn('custom-model');

      when(
        () => logger.prompt(
          'API key environment variable:',
          defaultValue: any<String>(named: 'defaultValue'),
        ),
      ).thenReturn('OPENAI_API_KEY');

      when(
        () => logger.chooseOne(
          'Do not translate phrases:',
          choices: any<List<String>>(named: 'choices'),
          defaultValue: any<String>(named: 'defaultValue'),
        ),
      ).thenReturn('Done');

      when(
        () => logger.prompt(
          'App context (optional):',
          defaultValue: any<String>(named: 'defaultValue'),
        ),
      ).thenReturn('');

      when(() => logger.success(any())).thenReturn(null);
      when(() => logger.info(any())).thenReturn(null);

      final command = ConfigCommand(logger: logger);
      await command.run();

      final content = File(
        p.join(tempDir.path, 'l10n.yaml'),
      ).readAsStringSync();
      expect(content, contains('model: custom-model'));
    });

    test('prefills existing config values in update mode', () async {
      // Create existing config
      File(p.join(tempDir.path, 'l10n.yaml')).writeAsStringSync(
        'arb-dir: lib/l10n\n'
        'template-arb-file: app_en.arb\n'
        'output-localization-file: app_localizations.dart\n'
        'ai_translation:\n'
        '  provider: openai\n'
        '  model: gpt-4.1-mini\n'
        '  api_key_env: OPENAI_API_KEY\n'
        '  context: Focus timer\n',
      );

      stubFullFlow(context: 'Updated context');

      final command = ConfigCommand(logger: logger);
      await command.run();

      // Verify chooseOne was called with defaultValue for provider
      verify(
        () => logger.chooseOne(
          'Select provider:',
          choices: any<List<String>>(named: 'choices'),
          defaultValue: 'openai',
        ),
      ).called(1);
    });

    test('handles add and remove phrases flow', () async {
      when(
        () => logger.chooseOne(
          'Select provider:',
          choices: any<List<String>>(named: 'choices'),
          defaultValue: any<String>(named: 'defaultValue'),
        ),
      ).thenReturn('openai');

      when(
        () => logger.chooseOne(
          'Select model:',
          choices: any<List<String>>(named: 'choices'),
          defaultValue: any<String>(named: 'defaultValue'),
        ),
      ).thenReturn('gpt-4.1-mini');

      when(
        () => logger.prompt(
          'API key environment variable:',
          defaultValue: any<String>(named: 'defaultValue'),
        ),
      ).thenReturn('OPENAI_API_KEY');

      // First call: Add phrase, second call: Done
      var callCount = 0;
      when(
        () => logger.chooseOne(
          'Do not translate phrases:',
          choices: any<List<String>>(named: 'choices'),
          defaultValue: any<String>(named: 'defaultValue'),
        ),
      ).thenAnswer((_) {
        callCount++;
        return callCount == 1 ? 'Add phrase' : 'Done';
      });

      when(() => logger.prompt('Enter phrase:')).thenReturn('Deep Work');

      when(
        () => logger.prompt(
          'App context (optional):',
          defaultValue: any<String>(named: 'defaultValue'),
        ),
      ).thenReturn('');

      when(() => logger.success(any())).thenReturn(null);
      when(() => logger.info(any())).thenReturn(null);

      final command = ConfigCommand(logger: logger);
      await command.run();

      final content = File(
        p.join(tempDir.path, 'l10n.yaml'),
      ).readAsStringSync();
      expect(content, contains('do_not_translate_phrases:'));
      expect(content, contains('    - Deep Work'));
    });
  });
}
