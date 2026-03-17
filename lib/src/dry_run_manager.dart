import 'dart:convert';
import 'dart:io';

import 'package:intl_ai/intl_ai.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

@immutable
class DryRunResult {
  const DryRunResult({
    required this.provider,
    required this.model,
    required this.templateLocale,
    required this.translations,
  });

  final AiTranslationProvider provider;
  final String model;
  final String templateLocale;
  final Map<String, Map<String, String>> translations;
}

class DryRunManager {
  DryRunManager({required this.arbDirectory});

  final String arbDirectory;

  static const _dryRunFilename = '.intl_ai_dry_run.json';

  String get _dryRunPath => p.join(arbDirectory, _dryRunFilename);

  void save({
    required AiTranslationProvider provider,
    required String model,
    required String templateLocale,
    required Map<String, Map<String, String>> translations,
  }) {
    final data = <String, dynamic>{
      'generated_at': DateTime.now().toUtc().toIso8601String(),
      'provider': provider.name,
      'model': model,
      'template_locale': templateLocale,
      'translations': translations,
    };

    File(
      _dryRunPath,
    ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(data));
  }

  DryRunResult? load() {
    final file = File(_dryRunPath);
    if (!file.existsSync()) return null;

    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

    final provider = AiTranslationProvider.tryParse(
      json['provider'] as String?,
    );
    if (provider == null) return null;

    final translationsRaw = json['translations'] as Map<String, dynamic>? ?? {};
    final translations = translationsRaw.map((locale, entries) {
      final entriesMap = (entries as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, value.toString()),
      );
      return MapEntry(locale, entriesMap);
    });

    return DryRunResult(
      provider: provider,
      model: json['model'] as String,
      templateLocale: json['template_locale'] as String,
      translations: translations,
    );
  }
}
