import 'dart:io';

import 'package:intl_ai/src/cldr_locales.dart';
import 'package:path/path.dart' as p;

String? getConfigDirectory() {
  var dir = Directory.current;
  while (true) {
    final candidate = p.join(dir.path, 'l10n.yaml');
    if (File(candidate).existsSync()) return dir.path;
    final parent = dir.parent;
    if (parent.path == dir.path) return null;
    dir = parent;
  }
}

String canonicalizeLocale(String locale) =>
    locale.replaceAll('-', '_').toLowerCase();

({String prefix, String locale}) parseLocaleFromFilename(String filename) {
  final name = p.basenameWithoutExtension(filename);
  final parts = name.split('_');

  for (var i = 0; i < parts.length; i++) {
    final candidate = parts.sublist(i).join('_');
    if (isKnownCldrLocale(candidate)) {
      return (
        prefix: parts.sublist(0, i).join('_'),
        locale: candidate,
      );
    }
  }

  return (
    prefix: parts.sublist(0, parts.length - 1).join('_'),
    locale: parts.last,
  );
}

bool isKnownCldrLocale(String locale) {
  final canonical = canonicalizeLocale(locale);
  if (kKnownCldrLocales.contains(canonical)) return true;

  final parts = canonical.split('_');
  for (var i = parts.length - 1; i >= 1; i--) {
    final prefix = parts.sublist(0, i).join('_');
    if (kKnownCldrLocales.contains(prefix)) return true;
  }

  return false;
}
