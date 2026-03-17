class ArbValidationResult {
  const ArbValidationResult({required this.isValid, this.error});

  final bool isValid;
  final String? error;

  @override
  String toString() => isValid ? 'valid' : 'invalid: $error';
}

class ArbValidator {
  /// Maps ICU exact-value plural selectors to their equivalent CLDR keyword
  /// categories. When both forms appear in the same plural message, the
  /// exact-value form is redundant and causes an ICU syntax warning.
  static const _redundantPluralExactValues = {
    '=0': 'zero',
    '=1': 'one',
    '=2': 'two',
  };

  static List<String> extractPlaceholders(String value) {
    final simple = RegExp(r'\{(\w+)\}');
    return simple.allMatches(value).map((m) => m.group(1)!).toSet().toList();
  }

  static String? validateIcuSyntax(String value) {
    var depth = 0;
    for (var i = 0; i < value.length; i++) {
      if (value[i] == '{') depth++;
      if (value[i] == '}') depth--;
      if (depth < 0) return 'unbalanced braces (extra closing brace at $i)';
    }
    if (depth != 0) return 'unbalanced braces (unclosed: $depth)';
    return null;
  }

  /// Removes redundant exact-value plural categories (=0, =1, =2) when
  /// the corresponding CLDR keyword (zero, one, two) is also present.
  static String removeRedundantPluralCategories(String value) {
    if (!value.contains('plural,')) return value;

    var result = value;
    for (final entry in _redundantPluralExactValues.entries) {
      final exactSelector = entry.key;
      final cldrKeyword = entry.value;

      final hasExactSelector = RegExp(
        '${RegExp.escape(exactSelector)}\\s*\\{',
      ).hasMatch(result);
      final hasCldrKeyword = RegExp('\\b$cldrKeyword\\s*\\{').hasMatch(result);

      if (hasExactSelector && hasCldrKeyword) {
        result = _removePluralSelector(result, exactSelector);
      }
    }

    return result;
  }

  static String _removePluralSelector(String value, String selector) {
    final pattern = RegExp('${RegExp.escape(selector)}\\s*\\{');
    final match = pattern.firstMatch(value);
    if (match == null) return value;

    final openingBrace = value.indexOf('{', match.start + selector.length);

    // Walk forward to find the matching closing brace
    var depth = 0;
    var closingBrace = -1;
    for (var i = openingBrace; i < value.length; i++) {
      if (value[i] == '{') depth++;
      if (value[i] == '}') {
        depth--;
        if (depth == 0) {
          closingBrace = i;
          break;
        }
      }
    }

    if (closingBrace == -1) return value;

    final before = value.substring(0, match.start).trimRight();
    final after = value.substring(closingBrace + 1).trimLeft();

    return '$before $after';
  }

  static ArbValidationResult validateTranslation(
    String sourceText,
    String translatedText,
  ) {
    final syntaxError = validateIcuSyntax(translatedText);
    if (syntaxError != null) {
      return ArbValidationResult(isValid: false, error: syntaxError);
    }

    final sourcePlaceholders = extractPlaceholders(sourceText);
    final translatedPlaceholders = extractPlaceholders(translatedText);

    for (final placeholder in sourcePlaceholders) {
      if (!translatedPlaceholders.contains(placeholder)) {
        return ArbValidationResult(
          isValid: false,
          error: 'missing placeholder: {$placeholder}',
        );
      }
    }

    return const ArbValidationResult(isValid: true);
  }
}
