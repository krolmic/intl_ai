import 'dart:io';

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

/// Normalizes a locale string to the lowercase, `_`-separated form used
/// throughout intl_ai (e.g. `de-DE` → `de_de`, `zh-Hans` → `zh_hans`).
String canonicalizeLocale(String locale) =>
    locale.replaceAll('-', '_').toLowerCase();
