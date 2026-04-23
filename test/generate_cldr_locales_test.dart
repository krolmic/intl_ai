import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../tool/generate_cldr_locales.dart';

class _MockHttpClient extends Mock implements HttpClient {}

class _MockHttpClientRequest extends Mock implements HttpClientRequest {}

class _FakeHttpClientResponse extends StreamView<List<int>>
    implements HttpClientResponse {
  _FakeHttpClientResponse(this.statusCode, String body)
    : super(Stream.value(utf8.encode(body)));

  @override
  final int statusCode;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUri extends Fake implements Uri {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeUri());
  });

  group('CldrLocaleRepository', () {
    late _MockHttpClient httpClient;
    late _MockHttpClientRequest httpRequest;
    late CldrLocaleRepository repository;

    setUp(() {
      httpClient = _MockHttpClient();
      httpRequest = _MockHttpClientRequest();
      repository = CldrLocaleRepository(httpClient: httpClient);
    });

    void stubResponse(_FakeHttpClientResponse response) {
      when(() => httpClient.getUrl(any())).thenAnswer((_) async => httpRequest);
      when(httpRequest.close).thenAnswer((_) async => response);
    }

    test('requests the CLDR availableLocales URL', () async {
      stubResponse(
        _FakeHttpClientResponse(200, '{"availableLocales":{"full":[]}}'),
      );

      await repository.getCanonicalLocales();

      verify(
        () => httpClient.getUrl(
          Uri.parse(
            'https://raw.githubusercontent.com/unicode-org/cldr-json/main/'
            'cldr-json/cldr-core/availableLocales.json',
          ),
        ),
      ).called(1);
    });

    test('returns canonicalized locales sorted alphabetically', () async {
      const payload = '''
{
  "availableLocales": {
    "full": ["zh-Hans", "en-US", "de-DE", "fr", "sr-Latn-RS"]
  }
}
''';
      stubResponse(_FakeHttpClientResponse(200, payload));

      final result = await repository.getCanonicalLocales();

      expect(
        result,
        equals(['de_de', 'en_us', 'fr', 'sr_latn_rs', 'zh_hans']),
      );
    });

    test('deduplicates locales that canonicalize to the same value', () async {
      const payload = '''
{
  "availableLocales": {
    "full": ["de-DE", "DE_de", "de_DE", "de-de"]
  }
}
''';
      stubResponse(_FakeHttpClientResponse(200, payload));

      final result = await repository.getCanonicalLocales();

      expect(result, equals(['de_de']));
    });

    test('returns an empty list when the CLDR payload is empty', () async {
      stubResponse(
        _FakeHttpClientResponse(200, '{"availableLocales":{"full":[]}}'),
      );

      final result = await repository.getCanonicalLocales();

      expect(result, isEmpty);
    });

    test('throws HttpException on non-200 response', () async {
      stubResponse(_FakeHttpClientResponse(500, ''));

      await expectLater(
        repository.getCanonicalLocales(),
        throwsA(
          isA<HttpException>().having(
            (e) => e.message,
            'message',
            contains('500'),
          ),
        ),
      );
    });

    test('throws on malformed JSON', () async {
      stubResponse(_FakeHttpClientResponse(200, 'not json'));

      await expectLater(
        repository.getCanonicalLocales(),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
