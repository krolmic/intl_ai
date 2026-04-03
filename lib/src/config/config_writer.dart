import 'dart:io';

import 'package:intl_ai/src/config/ai_translation_config.dart';

class ConfigWriter {
  static void writeAiTranslationSection(
    String yamlPath,
    AiTranslationConfig config,
  ) {
    final file = File(yamlPath);
    final section = _getAiTranslationSection(config);

    if (!file.existsSync()) {
      _createFileWithDefaults(file, section);
      return;
    }

    final lines = file.readAsLinesSync();
    final aiTranslationIndex = lines.indexWhere(
      (line) => line.trimRight() == 'ai_translation:',
    );

    if (aiTranslationIndex == -1) {
      _appendSectionToFile(file, section);
      return;
    }

    _replaceExistingSection(file, lines, aiTranslationIndex, section);
  }

  static void _createFileWithDefaults(File file, String section) {
    file.writeAsStringSync(
      'arb-dir: lib/l10n\n'
      'template-arb-file: app_en.arb\n'
      'output-localization-file: app_localizations.dart\n'
      '\n'
      '$section',
    );
  }

  static void _appendSectionToFile(File file, String section) {
    final content = file.readAsStringSync();
    final needsNewline = content.isNotEmpty && !content.endsWith('\n');
    file.writeAsStringSync(
      '${needsNewline ? '\n' : ''}\n$section',
      mode: FileMode.append,
    );
  }

  static void _replaceExistingSection(
    File file,
    List<String> lines,
    int sectionIndex,
    String section,
  ) {
    final before = lines.sublist(0, sectionIndex);
    var i = sectionIndex + 1;
    while (i < lines.length) {
      final line = lines[i];
      if (line.isEmpty || line.startsWith(' ') || line.startsWith('\t')) {
        i++;
      } else {
        break;
      }
    }
    final after = lines.sublist(i);

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

  static String _getAiTranslationSection(AiTranslationConfig config) {
    final buffer = StringBuffer()
      ..writeln('ai_translation:')
      ..writeln('  provider: ${config.provider.name}')
      ..writeln('  model: ${_escapeForYaml(config.model)}')
      ..writeln('  api_key_env: ${_escapeForYaml(config.apiKeyEnv)}');

    if (config.doNotTranslatePhrases.isNotEmpty) {
      buffer.writeln('  do_not_translate_phrases:');
      for (final phrase in config.doNotTranslatePhrases) {
        buffer.writeln('    - ${_escapeForYaml(phrase)}');
      }
    }

    if (config.context != null) {
      buffer.writeln('  context: ${_escapeForYaml(config.context!)}');
    }

    return buffer.toString();
  }

  static String _escapeForYaml(String value) {
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
