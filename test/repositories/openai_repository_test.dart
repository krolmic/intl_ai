import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl_ai/src/config/ai_translation_config.dart';
import 'package:intl_ai/src/intl_ai_exception.dart';
import 'package:intl_ai/src/repositories/openai_repository.dart';
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
      'provider': 'openai',
      'model': 'gpt-4.1-mini',
      'api_key_env': 'OPENAI_KEY',
    });
  });

  OpenAiRepository makeRepository({String apiKey = 'test-key'}) =>
      OpenAiRepository(
        httpClient: mockClient,
        apiKeyResolver: (_) => apiKey,
      );

  group('OpenAiRepository.getTranslations', () {
    test('returns parsed translations from valid response', () async {
      final translations = {
        'appTitle': 'Deep Work Timer',
        'cancel': 'Abbrechen',
      };
      final responseBody = jsonEncode({
        'choices': [
          {
            'message': {'content': jsonEncode(translations)},
          },
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
        targetLocale: 'de',
        config: config,
      );

      expect(result['appTitle'], 'Deep Work Timer');
      expect(result['cancel'], 'Abbrechen');
    });

    test('strips markdown fences from response', () async {
      const translations = '{"hello": "Hallo"}';
      const fencedContent = '```json\n$translations\n```';
      final responseBody = jsonEncode({
        'choices': [
          {
            'message': {'content': fencedContent},
          },
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
        targetLocale: 'de',
        config: config,
      );

      expect(result['hello'], 'Hallo');
    });

    test('throws StateError when api key is not set', () async {
      final repository = OpenAiRepository(
        httpClient: mockClient,
        apiKeyResolver: (_) => null,
      );

      expect(
        () => repository.getTranslations(
          keys: {'key': 'value'},
          sourceLocale: 'en',
          targetLocale: 'de',
          config: config,
        ),
        throwsA(
          isA<IntlAiException>().having(
            (e) => e.message,
            'message',
            contains('OPENAI_KEY'),
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
          targetLocale: 'de',
          config: config,
        ),
        throwsA(isA<IntlAiException>()),
      );
    });

    test('sends Authorization header with bearer token', () async {
      final responseBody = jsonEncode({
        'choices': [
          {
            'message': {'content': '{}'},
          },
        ],
      });

      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => http.Response(responseBody, 200));

      final repository = OpenAiRepository(
        httpClient: mockClient,
        apiKeyResolver: (_) => 'sk-secret',
      );
      await repository.getTranslations(
        keys: {},
        sourceLocale: 'en',
        targetLocale: 'de',
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
      expect(headers['Authorization'], 'Bearer sk-secret');
    });
  });
}
