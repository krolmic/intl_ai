import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl_ai/intl_ai.dart';
import 'package:intl_ai/src/repositories/anthropic_repository.dart';
import 'package:intl_ai/src/repositories/openai_repository.dart';

abstract class TranslationRepository {
  factory TranslationRepository.create(
    AiTranslationConfig config, {
    http.Client? httpClient,
  }) {
    switch (config.provider) {
      case AiTranslationProvider.openai:
        return OpenAiRepository(httpClient: httpClient);
      case AiTranslationProvider.anthropic:
        return AnthropicRepository(httpClient: httpClient);
    }
  }

  Future<Map<String, String>> getTranslations({
    required Map<String, String> keys,
    required String sourceLocale,
    required String targetLocale,
    required AiTranslationConfig config,
  });

  void close();

  static String getSystemPrompt({
    required String sourceLocale,
    required String targetLocale,
    required List<String> ignoreTerms,
    String? appContextDescription,
  }) {
    final contextLine =
        appContextDescription != null && appContextDescription.isNotEmpty
        ? 'App context: $appContextDescription\n'
        : '';

    final ignoreSection = ignoreTerms.isNotEmpty
        ? '\nNon-translatable terms:\n'
              '- Keep these terms exactly as written:'
              ' ${ignoreTerms.map((term) => '"$term"').join(', ')}.\n'
        : '';

    return 'You are a professional software localization expert'
        ' specializing in Flutter ARB files.\n'
        '\n'
        'Task: Translate JSON values'
        ' from $sourceLocale to $targetLocale.\n'
        '$contextLine'
        '\n'
        'Output format:\n'
        '- Return ONLY a valid JSON object.\n'
        '- Do NOT include markdown, comments,'
        ' explanations, or code fences.\n'
        '- The output must be directly machine-parseable.\n'
        '- Do not add, remove, or reorder keys.\n'
        '- All double quotes inside string values'
        r' MUST be escaped as \". The output must be'
        ' valid JSON that passes json.decode().\n'
        '\n'
        'Placeholders (CRITICAL):\n'
        '- Preserve all placeholders exactly as-is'
        ' (e.g. {duration}, {count}, {label}).\n'
        '- Do not translate, rename,'
        ' or reorder placeholders.\n'
        '\n'
        'ICU message syntax (CRITICAL):\n'
        '- Preserve ICU syntax exactly'
        ' (e.g. {count, plural, one{...} other{...}},'
        ' {gender, select, ...}).\n'
        '- Only translate human-readable text'
        ' inside ICU blocks.\n'
        '- For plural messages, use the correct CLDR plural'
        ' categories for the target locale'
        ' (e.g. one/few/many/other for Russian,'
        ' one/other for English).\n'
        '- Do NOT combine exact-value matches'
        ' (=0, =1, =2) with their corresponding'
        ' keyword categories (zero, one, two)'
        ' — use only the keyword form.\n'
        '$ignoreSection'
        '\n'
        'Style:\n'
        '- Use natural, concise UI phrasing'
        ' — avoid overly literal translations.\n'
        '- Maintain consistent terminology'
        ' across all keys.\n'
        '- Preserve punctuation, spacing,'
        ' and formatting unless localization'
        ' requires a change.\n'
        '\n'
        'Error handling:\n'
        '- If a value cannot be safely translated'
        ' due to malformed ICU or placeholders,'
        ' return it unchanged.';
  }

  static String getUserMessage({
    required Map<String, String> keys,
    required String sourceLocale,
    required String targetLocale,
  }) {
    return 'Translate the following JSON'
        ' from $sourceLocale to $targetLocale.\n'
        'Return ONLY a valid JSON object'
        ' with identical keys.\n\n'
        '${jsonEncode(keys)}';
  }
}
