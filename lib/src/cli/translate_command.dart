import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:intl_ai/src/cli/utils.dart';
import 'package:intl_ai/src/config/l10n_config.dart';
import 'package:intl_ai/src/intl_ai_exception.dart';
import 'package:intl_ai/src/translator.dart';
import 'package:logging/logging.dart';

class TranslateCommand extends Command<int> {
  TranslateCommand() {
    argParser
      ..addFlag(
        'full',
        help: 'Re-translate all keys (not just missing ones).',
        negatable: false,
      )
      ..addFlag(
        'dry-run',
        help: 'Translate but save to review file instead of writing ARB files.',
        negatable: false,
      )
      ..addFlag(
        'apply-dry-run',
        help: 'Apply a previously saved dry-run file to ARBs.',
        negatable: false,
      )
      ..addOption(
        'locale',
        help: 'Translate only a specific target locale (e.g. de).',
        valueHelp: 'code',
      )
      ..addFlag(
        'verbose',
        abbr: 'v',
        help: 'Print detailed progress.',
        negatable: false,
      );
  }

  @override
  String get name => 'translate';

  @override
  String get description =>
      'Translate ARB files using AI (OpenAI or Anthropic).';

  @override
  Future<int> run() async {
    final results = argResults!;
    final fullIsSet = results['full'] as bool;
    final dryRunIsSet = results['dry-run'] as bool;
    final applyDryRunIsSet = results['apply-dry-run'] as bool;
    final locale = results['locale'] as String?;
    final verboseIsSet = results['verbose'] as bool;

    Logger.root.level = verboseIsSet ? Level.ALL : Level.INFO;
    Logger.root.onRecord.listen((record) {
      final prefix = record.level >= Level.WARNING
          ? '${record.level.name}: '
          : '';
      stdout.writeln('$prefix${record.message}');
    });

    if (dryRunIsSet && applyDryRunIsSet) {
      stderr.writeln(
        'Error: --dry-run and --apply-dry-run cannot be used together.',
      );
      return 1;
    }

    final projectRoot = getConfigDirectory();
    if (projectRoot == null) {
      stderr.writeln(
        'Error: Could not find l10n.yaml. '
        'Run this command from your Flutter project root.',
      );
      return 1;
    }

    final L10nConfig config;
    try {
      config = L10nConfig.load(projectRoot);
    } on FileSystemException catch (e) {
      stderr.writeln('Error: ${e.message}: ${e.path}');
      return 1;
    } on FormatException catch (e) {
      stderr.writeln('Error: ${e.message}');
      return 1;
    }

    final translator = Translator(
      config: config,
      projectRoot: projectRoot,
    );

    try {
      if (applyDryRunIsSet) {
        await translator.applyDryRun();
      } else {
        await translator.translateLocales(
          retranslateAll: fullIsSet,
          dryRunIsEnabled: dryRunIsSet,
          targetLocale: locale,
        );
      }
    } on IntlAiException catch (e) {
      stderr.writeln('Error: ${e.message}');
      return 1;
    } finally {
      translator.close();
    }

    return 0;
  }
}
