import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:intl_ai/src/config/ai_translation_config.dart';
import 'package:intl_ai/src/intl_ai_exception.dart';
import 'package:intl_ai/src/repositories/translation_repository.dart';

class AnthropicRepository implements TranslationRepository {
  AnthropicRepository({
    http.Client? httpClient,
    String? Function(String)? apiKeyResolver,
  }) : _client = httpClient ?? http.Client(),
       _apiKeyResolver = apiKeyResolver ?? _defaultResolver;

  final http.Client _client;
  final String? Function(String) _apiKeyResolver;

  static String? _defaultResolver(String key) => Platform.environment[key];

  static const _endpoint = 'https://api.anthropic.com/v1/messages';
  static const _anthropicVersion = '2023-06-01';
  static const _maxRetries = 3;
  static const _retryDelays = [
    Duration(seconds: 1),
    Duration(seconds: 4),
    Duration(seconds: 16),
  ];

  @override
  Future<Map<String, String>> getTranslations({
    required Map<String, String> keys,
    required String sourceLocale,
    required String targetLocale,
    required AiTranslationConfig config,
  }) async {
    final apiKey = _apiKeyResolver(config.apiKeyEnv);
    if (apiKey == null || apiKey.isEmpty) {
      throw IntlAiException(
        'API key environment variable "${config.apiKeyEnv}" is not set.',
      );
    }

    final systemPrompt = TranslationRepository.getSystemPrompt(
      sourceLocale: sourceLocale,
      targetLocale: targetLocale,
      ignoreTerms: config.ignore,
      appContextDescription: config.context,
    );
    final userMessage = TranslationRepository.getUserMessage(
      keys: keys,
      sourceLocale: sourceLocale,
      targetLocale: targetLocale,
    );

    final body = jsonEncode({
      'model': config.model,
      'max_tokens': 8192,
      'system': systemPrompt,
      'messages': [
        {'role': 'user', 'content': userMessage},
      ],
    });

    http.Response? response;
    for (var attempt = 0; attempt < _maxRetries; attempt++) {
      response = await _client.post(
        Uri.parse(_endpoint),
        headers: {
          'x-api-key': apiKey,
          'anthropic-version': _anthropicVersion,
          'Content-Type': 'application/json',
        },
        body: body,
      );

      if (response.statusCode == 200) break;

      final shouldRetry =
          response.statusCode == 429 || response.statusCode >= 500;
      if (!shouldRetry || attempt == _maxRetries - 1) {
        throw IntlAiException(
          'Anthropic API error ${response.statusCode}: ${response.body}',
        );
      }
      await Future<void>.delayed(_retryDelays[attempt]);
    }

    final responseJson = jsonDecode(response!.body) as Map<String, dynamic>;
    _validateStopReason(responseJson['stop_reason'] as String?);
    final contentList = responseJson['content'] as List<dynamic>;
    final firstBlock = contentList[0] as Map<String, dynamic>;
    final content = firstBlock['text'] as String;

    return _getParsedResponse(content);
  }

  @override
  void close() => _client.close();

  static void _validateStopReason(String? stopReason) {
    if (stopReason == 'max_tokens') {
      throw const IntlAiException(
        'Anthropic response was truncated (stop_reason: max_tokens). '
        'The batch may be too large. '
        'Consider using a model with higher output limits.',
      );
    }
  }

  Map<String, String> _getParsedResponse(String content) {
    var cleanedContent = content.trim();
    if (cleanedContent.startsWith('```')) {
      final firstNewline = cleanedContent.indexOf('\n');
      if (firstNewline != -1) {
        cleanedContent = cleanedContent.substring(firstNewline + 1);
      }
      if (cleanedContent.endsWith('```')) {
        cleanedContent = cleanedContent
            .substring(0, cleanedContent.length - 3)
            .trim();
      }
    }

    final decoded = jsonDecode(cleanedContent) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, v.toString()));
  }
}
