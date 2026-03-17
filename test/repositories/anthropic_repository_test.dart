import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl_ai/src/config/ai_translation_config.dart';
import 'package:intl_ai/src/intl_ai_exception.dart';
import 'package:intl_ai/src/repositories/anthropic_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  late MockHttpClient mockClient;
  late AiTranslationConfig config;

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
    registerFallbackValue(<String, String>{});
  });

  setUp(() {
    mockClient = MockHttpClient();
    config = AiTranslationConfig.fromYaml(const {
      'provider': 'anthropic',
      'model': 'claude-3-haiku-20240307',
      'api_key_env': 'ANTHROPIC_KEY',
    });
  });

  AnthropicRepository makeRepository({String apiKey = 'test-key'}) =>
      AnthropicRepository(
        httpClient: mockClient,
        apiKeyResolver: (_) => apiKey,
      );

  group('AnthropicRepository.getTranslations', () {
    test('returns parsed translations from valid response', () async {
      final translations = {
        'appTitle': 'Deep Work Timer',
        'cancel': 'Annuler',
      };
      final responseBody = jsonEncode({
        'content': [
          {'text': jsonEncode(translations)},
        ],
      });

      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => http.Response(responseBody, 200));

      final repository = makeRepository();
      final result = await repository.getTranslations(
        keys: {'appTitle': 'Deep Work Timer', 'cancel': 'Cancel'},
        sourceLocale: 'en',
        targetLocale: 'fr',
        config: config,
      );

      expect(result['appTitle'], 'Deep Work Timer');
      expect(result['cancel'], 'Annuler');
    });

    test('strips markdown fences from response', () async {
      const translations = '{"hello": "Bonjour"}';
      const fencedContent = '```json\n$translations\n```';
      final responseBody = jsonEncode({
        'content': [
          {'text': fencedContent},
        ],
      });

      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => http.Response(responseBody, 200));

      final repository = makeRepository();
      final result = await repository.getTranslations(
        keys: {'hello': 'Hello'},
        sourceLocale: 'en',
        targetLocale: 'fr',
        config: config,
      );

      expect(result['hello'], 'Bonjour');
    });

    test('throws StateError when api key is not set', () async {
      final repository = AnthropicRepository(
        httpClient: mockClient,
        apiKeyResolver: (_) => null,
      );

      expect(
        () => repository.getTranslations(
          keys: {'key': 'value'},
          sourceLocale: 'en',
          targetLocale: 'fr',
          config: config,
        ),
        throwsA(
          isA<IntlAiException>().having(
            (e) => e.message,
            'message',
            contains('ANTHROPIC_KEY'),
          ),
        ),
      );
    });

    test('throws StateError on non-retryable API error', () async {
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => http.Response('{"error": "auth"}', 401));

      final repository = makeRepository();

      expect(
        () => repository.getTranslations(
          keys: {'key': 'value'},
          sourceLocale: 'en',
          targetLocale: 'fr',
          config: config,
        ),
        throwsA(isA<IntlAiException>()),
      );
    });

    test('sends x-api-key header', () async {
      final responseBody = jsonEncode({
        'content': [
          {'text': '{}'},
        ],
      });

      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => http.Response(responseBody, 200));

      final repository = AnthropicRepository(
        httpClient: mockClient,
        apiKeyResolver: (_) => 'ant-secret',
      );
      await repository.getTranslations(
        keys: {},
        sourceLocale: 'en',
        targetLocale: 'fr',
        config: config,
      );

      final captured = verify(
        () => mockClient.post(
          any(),
          headers: captureAny(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).captured;

      final headers = captured.first as Map<String, String>;
      expect(headers['x-api-key'], 'ant-secret');
    });
  });
}
