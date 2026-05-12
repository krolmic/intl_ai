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

  group('AiTranslationConfig equality', () {
    const baseConfig = AiTranslationConfig(
      provider: AiTranslationProvider.openai,
      model: 'gpt-4.1-mini',
      apiKeyEnv: 'OPENAI_API_KEY',
      doNotTranslatePhrases: ['Deep Work', 'Flutter'],
      context: 'A focus timer app',
    );

    test('identical instances are equal', () {
      expect(baseConfig, equals(baseConfig));
    });

    test('instances with identical field values are equal', () {
      final phrases = <String>['Deep Work', 'Flutter'];
      final other = AiTranslationConfig(
        provider: AiTranslationProvider.openai,
        model: 'gpt-4.1-mini',
        apiKeyEnv: 'OPENAI_API_KEY',
        doNotTranslatePhrases: phrases,
        context: 'A focus timer app',
      );
      expect(identical(baseConfig, other), isFalse);
      expect(baseConfig, equals(other));
      expect(baseConfig.hashCode, other.hashCode);
    });

    test('differs in provider', () {
      const other = AiTranslationConfig(
        provider: AiTranslationProvider.anthropic,
        model: 'gpt-4.1-mini',
        apiKeyEnv: 'OPENAI_API_KEY',
        doNotTranslatePhrases: ['Deep Work', 'Flutter'],
        context: 'A focus timer app',
      );
      expect(baseConfig, isNot(equals(other)));
    });

    test('differs in model', () {
      const other = AiTranslationConfig(
        provider: AiTranslationProvider.openai,
        model: 'gpt-4o',
        apiKeyEnv: 'OPENAI_API_KEY',
        doNotTranslatePhrases: ['Deep Work', 'Flutter'],
        context: 'A focus timer app',
      );
      expect(baseConfig, isNot(equals(other)));
    });

    test('differs in apiKeyEnv', () {
      const other = AiTranslationConfig(
        provider: AiTranslationProvider.openai,
        model: 'gpt-4.1-mini',
        apiKeyEnv: 'OTHER_KEY',
        doNotTranslatePhrases: ['Deep Work', 'Flutter'],
        context: 'A focus timer app',
      );
      expect(baseConfig, isNot(equals(other)));
    });

    test('differs in context', () {
      const otherWithDifferentContext = AiTranslationConfig(
        provider: AiTranslationProvider.openai,
        model: 'gpt-4.1-mini',
        apiKeyEnv: 'OPENAI_API_KEY',
        doNotTranslatePhrases: ['Deep Work', 'Flutter'],
        context: 'A different app',
      );
      const otherWithNullContext = AiTranslationConfig(
        provider: AiTranslationProvider.openai,
        model: 'gpt-4.1-mini',
        apiKeyEnv: 'OPENAI_API_KEY',
        doNotTranslatePhrases: ['Deep Work', 'Flutter'],
      );
      expect(baseConfig, isNot(equals(otherWithDifferentContext)));
      expect(baseConfig, isNot(equals(otherWithNullContext)));
    });

    test('differs in doNotTranslatePhrases contents', () {
      const other = AiTranslationConfig(
        provider: AiTranslationProvider.openai,
        model: 'gpt-4.1-mini',
        apiKeyEnv: 'OPENAI_API_KEY',
        doNotTranslatePhrases: ['Deep Work', 'Dart'],
        context: 'A focus timer app',
      );
      expect(baseConfig, isNot(equals(other)));
      expect(baseConfig.hashCode, isNot(other.hashCode));
    });

    test('differs in doNotTranslatePhrases length', () {
      const other = AiTranslationConfig(
        provider: AiTranslationProvider.openai,
        model: 'gpt-4.1-mini',
        apiKeyEnv: 'OPENAI_API_KEY',
        doNotTranslatePhrases: ['Deep Work'],
        context: 'A focus timer app',
      );
      expect(baseConfig, isNot(equals(other)));
    });

    test('differs in doNotTranslatePhrases order', () {
      const other = AiTranslationConfig(
        provider: AiTranslationProvider.openai,
        model: 'gpt-4.1-mini',
        apiKeyEnv: 'OPENAI_API_KEY',
        doNotTranslatePhrases: ['Flutter', 'Deep Work'],
        context: 'A focus timer app',
      );
      expect(baseConfig, isNot(equals(other)));
    });

    test('equal doNotTranslatePhrases from different list instances', () {
      final phrasesA = <String>['Deep Work', 'Flutter'];
      final phrasesB = <String>['Deep Work', 'Flutter'];
      final a = AiTranslationConfig(
        provider: AiTranslationProvider.openai,
        model: 'gpt-4.1-mini',
        apiKeyEnv: 'OPENAI_API_KEY',
        doNotTranslatePhrases: phrasesA,
        context: 'A focus timer app',
      );
      final b = AiTranslationConfig(
        provider: AiTranslationProvider.openai,
        model: 'gpt-4.1-mini',
        apiKeyEnv: 'OPENAI_API_KEY',
        doNotTranslatePhrases: phrasesB,
        context: 'A focus timer app',
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });
  });
}
