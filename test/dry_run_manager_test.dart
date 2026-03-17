import 'dart:io';

import 'package:intl_ai/intl_ai.dart';
import 'package:intl_ai/src/dry_run_manager.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late DryRunManager manager;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('intl_ai_dryrun_test_');
    manager = DryRunManager(arbDirectory: tempDir.path);
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('DryRunManager.save', () {
    test('creates dry-run JSON file', () {
      manager.save(
        provider: AiTranslationProvider.openai,
        model: 'gpt-4.1-mini',
        templateLocale: 'en',
        translations: {
          'de': {'appTitle': 'Deep Work Timer', 'cancel': 'Abbrechen'},
        },
      );

      final file = File(p.join(tempDir.path, '.intl_ai_dry_run.json'));
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(content, contains('"provider": "openai"'));
      expect(content, contains('"model": "gpt-4.1-mini"'));
      expect(content, contains('"template_locale": "en"'));
      expect(content, contains('"cancel": "Abbrechen"'));
    });
  });

  group('DryRunManager.load', () {
    test('returns null when no file exists', () {
      expect(manager.load(), isNull);
    });

    test('loads previously saved file', () {
      manager.save(
        provider: AiTranslationProvider.anthropic,
        model: 'claude-3',
        templateLocale: 'en',
        translations: {
          'fr': {'hello': 'Bonjour'},
        },
      );

      final result = manager.load();
      expect(result, isNotNull);
      expect(result!.provider, AiTranslationProvider.anthropic);
      expect(result.model, 'claude-3');
      expect(result.templateLocale, 'en');
      expect(result.translations['fr']?['hello'], 'Bonjour');
    });
  });
}
