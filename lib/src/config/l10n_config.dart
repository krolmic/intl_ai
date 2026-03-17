import 'dart:io';

import 'package:intl_ai/src/config/ai_translation_config.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

class L10nConfig {
  const L10nConfig({
    required this.arbDirectory,
    required this.templateArbFile,
    required this.outputLocalizationFile,
    required this.aiTranslationConfig,
  });

  factory L10nConfig.load(String projectRoot) {
    final yamlPath = p.join(projectRoot, 'l10n.yaml');
    final file = File(yamlPath);
    if (!file.existsSync()) {
      throw FileSystemException('l10n.yaml not found', yamlPath);
    }

    final content = file.readAsStringSync();
    final yaml = loadYaml(content);
    if (yaml is! Map) {
      throw const FormatException('l10n.yaml must be a YAML map');
    }

    final arbDirRaw = yaml['arb-dir'] as String? ?? 'lib/l10n';
    final arbDir = p.isAbsolute(arbDirRaw)
        ? arbDirRaw
        : p.join(projectRoot, arbDirRaw);

    final templateArbFile =
        yaml['template-arb-file'] as String? ?? 'app_en.arb';
    final outputLocalizationFile =
        yaml['output-localization-file'] as String? ?? 'app_localizations.dart';

    final aiTranslationRaw = yaml['ai_translation'];
    if (aiTranslationRaw == null) {
      throw const FormatException(
        'l10n.yaml is missing the required ai_translation section',
      );
    }
    if (aiTranslationRaw is! Map) {
      throw const FormatException(
        'ai_translation in l10n.yaml must be a map',
      );
    }

    final aiTranslation = AiTranslationConfig.fromYaml(
      Map<dynamic, dynamic>.from(aiTranslationRaw),
    );

    return L10nConfig(
      arbDirectory: arbDir,
      templateArbFile: templateArbFile,
      outputLocalizationFile: outputLocalizationFile,
      aiTranslationConfig: aiTranslation,
    );
  }

  final String arbDirectory;
  final String templateArbFile;
  final String outputLocalizationFile;
  final AiTranslationConfig aiTranslationConfig;

  String get templateLocale {
    final name = p.basenameWithoutExtension(templateArbFile);
    final parts = name.split('_');
    return parts.last;
  }

  String get arbPrefix {
    final name = p.basenameWithoutExtension(templateArbFile);
    final parts = name.split('_');
    return parts.sublist(0, parts.length - 1).join('_');
  }
}
