import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:intl_ai/src/cli/project_root.dart';
import 'package:intl_ai/src/config/ai_translation_config.dart';
import 'package:intl_ai/src/config/config_writer.dart';
import 'package:intl_ai/src/config/l10n_config.dart';
import 'package:intl_ai/src/config/model_options.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

class ConfigCommand extends Command<int> {
  ConfigCommand({Logger? logger}) : _logger = logger ?? Logger();

  final Logger _logger;

  @override
  String get name => 'config';

  @override
  String get description =>
      'Interactively create or update the ai_translation config in l10n.yaml.';

  @override
  Future<int> run() async {
    final projectRoot = findProjectRoot();
    final yamlPath = projectRoot != null
        ? p.join(projectRoot, 'l10n.yaml')
        : p.join(Directory.current.path, 'l10n.yaml');

    final existing = _tryLoadExistingConfig(projectRoot);

    final provider = _promptProvider(existing?.provider);
    final model = _promptModel(provider, existing?.model);
    final apiKeyEnv = _promptApiKeyEnv(provider, existing?.apiKeyEnv);
    final doNotTranslatePhrases = _promptDoNotTranslatePhrases(
      existing?.doNotTranslatePhrases ?? [],
    );
    final context = _promptContext(existing?.context);

    final config = AiTranslationConfig(
      provider: provider,
      model: model,
      apiKeyEnv: apiKeyEnv,
      doNotTranslatePhrases: doNotTranslatePhrases,
      context: context,
    );

    ConfigWriter.writeAiTranslationSection(yamlPath, config);

    _logger.success('Config saved to $yamlPath');
    return 0;
  }

  AiTranslationConfig? _tryLoadExistingConfig(String? projectRoot) {
    if (projectRoot == null) return null;
    try {
      final config = L10nConfig.load(projectRoot);
      return config.aiTranslationConfig;
    } on Exception {
      return null;
    }
  }

  AiTranslationProvider _promptProvider(AiTranslationProvider? current) {
    final choices = AiTranslationProvider.values.map((e) => e.name).toList();
    final result = _logger.chooseOne(
      'Select provider:',
      choices: choices,
      defaultValue: current?.name,
    );
    return AiTranslationProvider.values.firstWhere((e) => e.name == result);
  }

  String _promptModel(AiTranslationProvider provider, String? current) {
    final models = switch (provider) {
      AiTranslationProvider.openai => openaiModels,
      AiTranslationProvider.anthropic => anthropicModels,
    };

    final choices = [...models, otherModelOption];

    // If current value exists but isn't in the list, add it
    if (current != null && !models.contains(current)) {
      choices.insert(0, current);
    }

    final defaultValue = current != null && choices.contains(current)
        ? current
        : null;

    final result = _logger.chooseOne(
      'Select model:',
      choices: choices,
      defaultValue: defaultValue,
    );

    if (result == otherModelOption) {
      return _logger.prompt('Enter model name:');
    }

    return result;
  }

  String _promptApiKeyEnv(AiTranslationProvider provider, String? current) {
    final providerDefault = switch (provider) {
      AiTranslationProvider.openai => 'OPENAI_API_KEY',
      AiTranslationProvider.anthropic => 'ANTHROPIC_API_KEY',
    };

    return _logger.prompt(
      'API key environment variable:',
      defaultValue: current ?? providerDefault,
    );
  }

  List<String> _promptDoNotTranslatePhrases(List<String> current) {
    final phrases = [...current];

    if (phrases.isNotEmpty) {
      _logger.info('Current phrases: ${phrases.join(', ')}');
    }

    while (true) {
      final choices = [
        'Add phrase',
        if (phrases.isNotEmpty) 'Remove phrase',
        'Done',
      ];

      final action = _logger.chooseOne(
        'Do not translate phrases:',
        choices: choices,
        defaultValue: 'Done',
      );

      if (action == 'Done') break;

      if (action == 'Add phrase') {
        final phrase = _logger.prompt('Enter phrase:');
        if (phrase.isNotEmpty) {
          phrases.add(phrase);
          _logger.info('Added: $phrase');
        }
      } else if (action == 'Remove phrase') {
        final toRemove = _logger.chooseOne(
          'Select phrase to remove:',
          choices: phrases,
        );
        phrases.remove(toRemove);
        _logger.info('Removed: $toRemove');
      }
    }

    return phrases;
  }

  String? _promptContext(String? current) {
    final result = _logger.prompt(
      'App context (optional):',
      defaultValue: current ?? '',
    );
    return result.isEmpty ? null : result;
  }
}
