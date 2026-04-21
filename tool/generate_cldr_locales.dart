import 'dart:convert';
import 'dart:io';

const _sourceUrl =
    'https://raw.githubusercontent.com/unicode-org/cldr-json/main/'
    'cldr-json/cldr-core/availableLocales.json';

Future<void> main() async {
  final client = HttpClient();
  final request = await client.getUrl(Uri.parse(_sourceUrl));
  final response = await request.close();
  if (response.statusCode != 200) {
    stderr.writeln('Failed to fetch CLDR data: ${response.statusCode}');
    exitCode = 1;
    client.close();
    return;
  }
  final body = await response.transform(utf8.decoder).join();
  client.close();

  final json = jsonDecode(body) as Map<String, dynamic>;
  final available = json['availableLocales'] as Map<String, dynamic>;
  final modern = (available['modern'] as List).cast<String>();
  final full = (available['full'] as List).cast<String>();
  final source = modern.isNotEmpty ? modern : full;

  final canonical =
      source.map((l) => l.replaceAll('-', '_').toLowerCase()).toSet().toList()
        ..sort();

  final buffer = StringBuffer()
    ..writeln(
      '// GENERATED — do not edit. '
      'Run `dart run tool/generate_cldr_locales.dart` to regenerate.',
    )
    ..writeln()
    ..writeln('const Set<String> kKnownCldrLocales = {');
  for (final locale in canonical) {
    buffer.writeln("  '$locale',");
  }
  buffer.writeln('};');

  stdout.write(buffer.toString());
}
