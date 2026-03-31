import 'package:intl_ai/src/config/ai_translation_config.dart';
import 'package:test/test.dart';

void main() {
  group('AiTranslationConfig.fromYaml', () {
    test('parses all fields correctly', () {
      final config = AiTranslationConfig.fromYaml(const {
        'provider': 'openai',
        'model': 'gpt-4.1-mini',
        'api_key_env': 'OPENAI_API_KEY',
        'do_not_translate_phrases': ['Deep Work', 'Flutter'],
        'context': 'A focus timer app',
      });

      expect(config.provider, AiTranslationProvider.openai);
      expect(config.model, 'gpt-4.1-mini');
      expect(config.apiKeyEnv, 'OPENAI_API_KEY');
      expect(config.doNotTranslatePhrases, ['Deep Work', 'Flutter']);
      expect(config.context, 'A focus timer app');
    });

    test('parses without optional fields', () {
      final config = AiTranslationConfig.fromYaml(const {
        'provider': 'anthropic',
        'model': 'claude-3-haiku-20240307',
        'api_key_env': 'ANTHROPIC_API_KEY',
      });

      expect(config.provider, AiTranslationProvider.anthropic);
      expect(config.doNotTranslatePhrases, isEmpty);
      expect(config.context, isNull);
    });

    test('throws when provider is missing', () {
      expect(
        () => AiTranslationConfig.fromYaml(const {
          'model': 'gpt-4',
          'api_key_env': 'KEY',
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws when provider is invalid', () {
      expect(
        () => AiTranslationConfig.fromYaml(const {
          'provider': 'gemini',
          'model': 'gemini-pro',
          'api_key_env': 'KEY',
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws when model is missing', () {
      expect(
        () => AiTranslationConfig.fromYaml(const {
          'provider': 'openai',
          'api_key_env': 'KEY',
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws when api_key_env is missing', () {
      expect(
        () => AiTranslationConfig.fromYaml(const {
          'provider': 'openai',
          'model': 'gpt-4',
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws when do_not_translate_phrases is not a list', () {
      expect(
        () => AiTranslationConfig.fromYaml(const {
          'provider': 'openai',
          'model': 'gpt-4',
          'api_key_env': 'KEY',
          'do_not_translate_phrases': 'single string',
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
