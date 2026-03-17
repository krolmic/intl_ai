import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

class ArbFile {
  ArbFile({
    required this.locale,
    required this.entries,
    required this.metadata,
  });

  factory ArbFile.fromFile(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      throw FileSystemException('ARB file not found', path);
    }

    final content = file.readAsStringSync();
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      throw FormatException('Failed to parse ARB file at $path: $e');
    }

    final locale =
        (json['@@locale'] as String?) ?? _localeFromFilename(p.basename(path));
    final entries = <String, String>{};
    final metadata = <String, dynamic>{};

    for (final entry in json.entries) {
      if (entry.key.startsWith('@')) {
        metadata[entry.key] = entry.value;
      } else {
        entries[entry.key] = entry.value.toString();
      }
    }

    return ArbFile(locale: locale, entries: entries, metadata: metadata);
  }

  final String locale;
  final Map<String, String> entries;
  final Map<String, dynamic> metadata;

  List<String> get allKeys => entries.keys.toList();

  List<String> getMissingKeys(ArbFile other) {
    return entries.keys
        .where((key) => !other.entries.containsKey(key))
        .toList();
  }

  void writeToFile(String path) {
    final lines = <String>['    "@@locale": "$locale"'];

    for (final key in entries.keys) {
      final value = entries[key]!;
      lines.add('    ${jsonEncode(key)}: ${jsonEncode(value)}');
      final metaKey = '@$key';
      if (metadata.containsKey(metaKey)) {
        final metaValue = metadata[metaKey];
        lines.add('    ${jsonEncode(metaKey)}: ${jsonEncode(metaValue)}');
      }
    }

    File(path).writeAsStringSync('{\n${lines.join(',\n')}\n}\n');
  }

  static String _localeFromFilename(String basename) {
    final name = p.basenameWithoutExtension(basename);
    final parts = name.split('_');
    return parts.last;
  }
}
