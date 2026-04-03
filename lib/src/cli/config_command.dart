import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:intl_ai/src/cli/utils.dart';
import 'package:intl_ai/src/config/ai_translation_config.dart';
import 'package:intl_ai/src/config/config_writer.dart';
import 'package:intl_ai/src/config/l10n_config.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

const _anthropicModels = <String>[
  'claude-opus-4-6',
  'claude-sonnet-4-6',
  'claude-haiku-4-5-20251001',
  'claude-sonnet-4-5-20250929',
  'claude-opus-4-5-20251101',
  'claude-opus-4-1-20250805',
  'claude-sonnet-4-20250514',
  'claude-opus-4-20250514',
];

const _openaiModels = <String>[
  'gpt-5.4',
  'gpt-5.4-pro',
  'gpt-5.4-mini',
  'gpt-5.4-nano',
  'gpt-5-mini',
  'gpt-5-nano',
  'gpt-5',
  'gpt-4.1',
  'gpt-5.2',
  'gpt-5.1',
  'gpt-5.2-pro',
  'gpt-5-pro',
  'o3-pro',
  'o3',
  'o4-mini',
  'gpt-4.1-mini',
  'gpt-4.1-nano',
  'o3-mini',
  'o1',
  'gpt-4o',
  'gpt-4o-mini',
  'gpt-4-turbo',
  'gpt-3.5-turbo',
  'gpt-4',
];

const _otherModelOption = 'Other (enter manually)';

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
    final configDirectory = getConfigDirectory();
    final yamlPath = configDirectory != null
        ? p.join(configDirectory, 'l10n.yaml')
        : p.join(Directory.current.path, 'l10n.yaml');

    final existing = _tryLoadExistingConfig(configDirectory);

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

  AiTranslationConfig? _tryLoadExistingConfig(String? configDirectory) {
    if (configDirectory == null) return null;
    try {
      final config = L10nConfig.load(configDirectory);
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
      AiTranslationProvider.openai => _openaiModels,
      AiTranslationProvider.anthropic => _anthropicModels,
    };

    final choices = [...models, _otherModelOption];

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

    if (result == _otherModelOption) {
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
