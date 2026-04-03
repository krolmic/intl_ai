import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:intl_ai/src/cli/config_command.dart';
import 'package:intl_ai/src/cli/translate_command.dart';

Future<void> main(List<String> arguments) async {
  final runner = CommandRunner<int>(
    'intl_ai',
    'ARB files translation with AI',
  )
    ..addCommand(TranslateCommand())
    ..addCommand(ConfigCommand());

  try {
    final exitCode = await runner.run(arguments) ?? 0;
    exit(exitCode);
  } on UsageException catch (e) {
    stderr
      ..writeln(e.message)
      ..writeln(e.usage);
    exit(64);
  }
}
