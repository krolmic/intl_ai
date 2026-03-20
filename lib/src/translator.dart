import 'dart:io';

import 'package:intl_ai/src/arb_file.dart';
import 'package:intl_ai/src/arb_validator.dart';
import 'package:intl_ai/src/config/l10n_config.dart';
import 'package:intl_ai/src/dry_run_manager.dart';
import 'package:intl_ai/src/intl_ai_exception.dart';
import 'package:intl_ai/src/repositories/translation_repository.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

class Translator {
  Translator({
    required this.config,
    required this.projectRoot,
    TranslationRepository? repository,
  }) : _repository =
           repository ??
           TranslationRepository.create(config.aiTranslationConfig);

  static final _log = Logger('IntlAi.Translator');

  final L10nConfig config;
  final String projectRoot;

  final TranslationRepository _repository;

  late final _dryRunManager = DryRunManager(
    arbDirectory: config.arbDirectory,
  );

  static const _batchSize = 100;

  void close() => _repository.close();

  Future<void> translateLocales({
    bool retranslateAll = false,
    bool dryRunIsEnabled = false,
    String? targetLocale,
  }) async {
    final templatePath = p.join(config.arbDirectory, config.templateArbFile);
    final template = ArbFile.fromFile(templatePath);

    final allLocales = _detectTargetLocales();
    final localesToProcess = targetLocale != null ? [targetLocale] : allLocales;

    final dryRunTranslations = <String, Map<String, String>>{};

    for (final locale in localesToProcess) {
      final targetFilename = '${config.arbPrefix}_$locale.arb';
      final targetPath = p.join(config.arbDirectory, targetFilename);

      final ArbFile existingArbFile;
      if (File(targetPath).existsSync()) {
        existingArbFile = ArbFile.fromFile(targetPath);
      } else {
        existingArbFile = ArbFile(locale: locale, entries: {}, metadata: {});
      }

      final keysToTranslate = retranslateAll
          ? template.allKeys
          : template.getMissingKeys(existingArbFile);

      if (keysToTranslate.isEmpty) {
        _log.fine(() => '[$locale] No keys to translate.');
        continue;
      }

      _log.fine(
        () => '[$locale] Translating ${keysToTranslate.length} key(s)...',
      );

      final entriesToTranslate = {
        for (final key in keysToTranslate) key: template.entries[key]!,
      };

      final translated = await _translateAllEntries(
        entriesToTranslate: entriesToTranslate,
        targetLocale: locale,
      );

      final validatedTranslations = <String, String>{};
      for (final key in keysToTranslate) {
        final sourceText = template.entries[key]!;
        final rawTranslatedText = translated[key];

        if (rawTranslatedText == null) {
          _log.warning(
            '[$locale] Missing translation for key "$key". '
            'Keeping source text.',
          );
          validatedTranslations[key] = sourceText;
          continue;
        }

        final translatedText = ArbValidator.removeRedundantPluralCategories(
          rawTranslatedText,
        );

        final result = ArbValidator.validateTranslation(
          sourceText,
          translatedText,
        );
        if (!result.isValid) {
          _log.warning(
            '[$locale] Validation failed for key "$key": '
            '${result.error}. Keeping '
            '${existingArbFile.entries.containsKey(key) //
                ? "existing" : "source"} text.',
          );
          validatedTranslations[key] =
              existingArbFile.entries[key] ?? sourceText;
        } else {
          validatedTranslations[key] = translatedText;
        }
      }

      _log.fine(
        () =>
            '[$locale] Translation complete for '
            '${validatedTranslations.length} key(s).',
      );

      if (dryRunIsEnabled) {
        dryRunTranslations[locale] = validatedTranslations;
      } else {
        _writeMergedArbFile(
          outputPath: targetPath,
          locale: locale,
          existingArbFile: existingArbFile,
          newTranslations: validatedTranslations,
        );
        _log.fine(() => '[$locale] Wrote $targetPath');
      }
    }

    if (dryRunIsEnabled && dryRunTranslations.isNotEmpty) {
      _dryRunManager.save(
        provider: config.aiTranslationConfig.provider,
        model: config.aiTranslationConfig.model,
        templateLocale: config.templateLocale,
        translations: dryRunTranslations,
      );
      _log
        ..info(
          'Dry-run complete. Review file saved to '
          '${p.join(config.arbDirectory, '.intl_ai_dry_run.json')}',
        )
        ..info(
          'Run `dart run intl_ai translate --apply-dry-run` to apply.',
        );
    }
  }

  Future<void> applyDryRun() async {
    final dryRunResult = _dryRunManager.load();

    if (dryRunResult == null) {
      throw IntlAiException(
        'No dry-run file found at '
        '${p.join(config.arbDirectory, ".intl_ai_dry_run.json")}. '
        'Run `dart run intl_ai translate --dry-run` first.',
      );
    }

    for (final entry in dryRunResult.translations.entries) {
      final locale = entry.key;
      final translations = entry.value;
      final targetFilename = '${config.arbPrefix}_$locale.arb';
      final targetPath = p.join(config.arbDirectory, targetFilename);

      final ArbFile existingArbFile;
      if (File(targetPath).existsSync()) {
        existingArbFile = ArbFile.fromFile(targetPath);
      } else {
        existingArbFile = ArbFile(locale: locale, entries: {}, metadata: {});
      }

      _writeMergedArbFile(
        outputPath: targetPath,
        locale: locale,
        existingArbFile: existingArbFile,
        newTranslations: translations,
      );
      _log.fine(
        () => '[$locale] Applied dry-run translations to $targetPath',
      );
    }

    _log.info('Dry-run applied successfully.');
  }

  void _writeMergedArbFile({
    required String outputPath,
    required String locale,
    required ArbFile existingArbFile,
    required Map<String, String> newTranslations,
  }) {
    final mergedEntries = Map<String, String>.from(existingArbFile.entries)
      ..addAll(newTranslations);

    ArbFile(
      locale: locale,
      entries: mergedEntries,
      metadata: {'@@locale': locale},
    ).writeToFile(outputPath);
  }

  List<String> _detectTargetLocales() {
    final dir = Directory(config.arbDirectory);
    if (!dir.existsSync()) {
      throw FileSystemException('ARB directory not found', config.arbDirectory);
    }

    final templateBasename = p.basename(config.templateArbFile);
    final templateName = p.basenameWithoutExtension(templateBasename);
    final parts = templateName.split('_');
    final prefix = parts.sublist(0, parts.length - 1).join('_');
    final templateLocale = parts.last;

    final locales = <String>[];
    for (final entity in dir.listSync()) {
      if (entity is! File) continue;
      final basename = p.basename(entity.path);
      if (!basename.endsWith('.arb')) continue;
      if (basename == templateBasename) continue;

      final name = p.basenameWithoutExtension(basename);
      if (!name.startsWith('${prefix}_')) continue;

      final locale = name.substring(prefix.length + 1);
      if (locale.isNotEmpty && locale != templateLocale) {
        locales.add(locale);
      }
    }

    return locales..sort();
  }

  Future<Map<String, String>> _translateAllEntries({
    required Map<String, String> entriesToTranslate,
    required String targetLocale,
  }) async {
    final keys = entriesToTranslate.keys.toList();
    final result = <String, String>{};

    for (var i = 0; i < keys.length; i += _batchSize) {
      final batchEntryKeys = keys.skip(i).take(_batchSize).toList();
      final batchEntries = {
        for (final key in batchEntryKeys) key: entriesToTranslate[key]!,
      };

      if (keys.length > _batchSize) {
        _log.fine(
          () =>
              '[$targetLocale] Batch ${i ~/ _batchSize + 1}: '
              '${batchEntryKeys.length} keys...',
        );
      }

      final batchResult = await _repository.getTranslations(
        keys: batchEntries,
        sourceLocale: config.templateLocale,
        targetLocale: targetLocale,
        config: config.aiTranslationConfig,
      );

      result.addAll(batchResult);
    }

    return result;
  }
}
