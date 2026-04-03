import 'dart:io';

import 'package:intl_ai/src/config/ai_translation_config.dart';

class ConfigWriter {
  static void writeAiTranslationSection(
    String yamlPath,
    AiTranslationConfig config,
  ) {
    final file = File(yamlPath);
    final section = _buildAiTranslationSection(config);

    if (!file.existsSync()) {
      file.writeAsStringSync(
        'arb-dir: lib/l10n\n'
        'template-arb-file: app_en.arb\n'
        'output-localization-file: app_localizations.dart\n'
        '\n'
        '$section',
      );
      return;
    }

    final lines = file.readAsLinesSync();
    final aiTranslationIndex = lines.indexWhere(
      (line) => line.trimRight() == 'ai_translation:',
    );

    if (aiTranslationIndex == -1) {
      // Append to existing file
      final content = file.readAsStringSync();
      final needsNewline = content.isNotEmpty && !content.endsWith('\n');
      file.writeAsStringSync(
        '${needsNewline ? '\n' : ''}\n$section',
        mode: FileMode.append,
      );
      return;
    }

    // Replace existing ai_translation section
    final before = lines.sublist(0, aiTranslationIndex);
    final after = <String>[];
    var i = aiTranslationIndex + 1;
    // Skip all indented lines (part of ai_translation section)
    while (i < lines.length) {
      final line = lines[i];
      if (line.isEmpty || line.startsWith(' ') || line.startsWith('\t')) {
        i++;
      } else {
        break;
      }
    }
    after.addAll(lines.sublist(i));

    final buffer = StringBuffer()
      ..writeAll(before.map((line) => '$line\n'))
      ..write(section);
    if (after.isNotEmpty) {
      buffer
        ..writeln()
        ..writeAll(after.map((line) => '$line\n'));
    }

    file.writeAsStringSync(buffer.toString());
  }

  static String _buildAiTranslationSection(AiTranslationConfig config) {
    final buffer = StringBuffer()
      ..writeln('ai_translation:')
      ..writeln('  provider: ${config.provider.name}')
      ..writeln('  model: ${_quoteIfNeeded(config.model)}')
      ..writeln('  api_key_env: ${_quoteIfNeeded(config.apiKeyEnv)}');

    if (config.doNotTranslatePhrases.isNotEmpty) {
      buffer.writeln('  do_not_translate_phrases:');
      for (final phrase in config.doNotTranslatePhrases) {
        buffer.writeln('    - ${_quoteIfNeeded(phrase)}');
      }
    }

    if (config.context != null) {
      buffer.writeln('  context: ${_quoteIfNeeded(config.context!)}');
    }

    return buffer.toString();
  }

  static String _quoteIfNeeded(String value) {
    if (value.contains(': ') ||
        value.contains('#') ||
        value.startsWith(' ') ||
        value.endsWith(' ') ||
        value.startsWith('"') ||
        value.startsWith("'")) {
      final escaped = value.replaceAll('"', r'\"');
      return '"$escaped"';
    }
    return value;
  }
}
