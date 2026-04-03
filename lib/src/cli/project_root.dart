import 'dart:io';

import 'package:path/path.dart' as p;

/// Walks up from the current directory looking for `l10n.yaml`.
/// Returns the directory path containing it, or `null` if not found.
String? findProjectRoot() {
  var dir = Directory.current;
  while (true) {
    final candidate = p.join(dir.path, 'l10n.yaml');
    if (File(candidate).existsSync()) return dir.path;
    final parent = dir.parent;
    if (parent.path == dir.path) return null;
    dir = parent;
  }
}
