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
