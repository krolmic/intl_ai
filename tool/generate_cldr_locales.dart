import 'dart:convert';
import 'dart:io';

import 'package:intl_ai/src/utils.dart';

class CldrLocaleRepository {
  CldrLocaleRepository({required HttpClient httpClient})
    : _httpClient = httpClient;

  static const _availableLocalesUrl =
      'https://raw.githubusercontent.com/unicode-org/cldr-json/main/'
      'cldr-json/cldr-core/availableLocales.json';

  final HttpClient _httpClient;

  Future<List<String>> getCanonicalLocales() async {
    final request = await _httpClient.getUrl(Uri.parse(_availableLocalesUrl));
    final response = await request.close();
    if (response.statusCode != 200) {
      throw HttpException(
        'Failed to fetch CLDR data: HTTP ${response.statusCode}',
        uri: Uri.parse(_availableLocalesUrl),
      );
    }
    final body = await response.transform(utf8.decoder).join();

    final payload = jsonDecode(body) as Map<String, dynamic>;
    final availableLocales =
        payload['availableLocales'] as Map<String, dynamic>;
    final rawLocales = (availableLocales['full'] as List).cast<String>();

    return rawLocales.map(canonicalizeLocale).toSet().toList()..sort();
  }
}

Future<void> main() async {
  final httpClient = HttpClient();
  final repository = CldrLocaleRepository(httpClient: httpClient);

  final List<String> canonicalLocales;
  try {
    canonicalLocales = await repository.getCanonicalLocales();
  } on HttpException catch (error) {
    stderr.writeln(error.message);
    exitCode = 1;
    return;
  } finally {
    httpClient.close();
  }

  final buffer = StringBuffer()
    ..writeln(
      '// GENERATED — do not edit. '
      'Run `dart run tool/generate_cldr_locales.dart` to regenerate.',
    )
    ..writeln()
    ..writeln('const Set<String> kKnownCldrLocales = {');
  for (final locale in canonicalLocales) {
    buffer.writeln("  '$locale',");
  }
  buffer.writeln('};');

  stdout.write(buffer.toString());
}
