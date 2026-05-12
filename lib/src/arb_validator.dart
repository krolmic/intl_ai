import 'dart:collection';

// We access package:intl's plural-rule registry directly to detect whether a
// locale has CLDR plural rules and to probe its supported categories.
// There is no public API for this.
import 'package:intl/src/plural_rules.dart' as plural_rules;
import 'package:intl_ai/src/utils.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';

class ArbValidationResult {
  const ArbValidationResult({required this.isValid, this.error});

  final bool isValid;
  final String? error;

  @override
  String toString() => isValid ? 'valid' : 'invalid: $error';
}

class ArbValidator {
  static final _log = Logger('IntlAi.ArbValidator');

  /// Maps ICU exact-value plural selectors to their equivalent CLDR keyword
  /// categories. When both forms appear in the same plural message, the
  /// exact-value form is redundant and causes an ICU syntax warning.
  static const _redundantPluralExactValues = {
    '=0': 'zero',
    '=1': 'one',
    '=2': 'two',
  };

  static const _pluralSelectGenderTypes = {'plural', 'select', 'gender'};

  static const _cldrCategoryOrder = [
    'zero',
    'one',
    'two',
    'few',
    'many',
    'other',
  ];

  // Probe numbers chosen to flush out every CLDR category across the locales
  // intl supports: integers cover one/two/few/many ranges (e.g. 5–6 for pl
  // MANY, 11/21 for ru, 1_000_000 for fr/pt MANY), fractions force the
  // non-integer OTHER cases.
  static const _pluralCategoryProbeNumbers = <num>[
    0,
    1,
    2,
    3,
    5,
    6,
    11,
    21,
    100,
    101,
    1000,
    1000000,
    1.5,
    2.5,
  ];

  static final Map<String, Set<String>?> _pluralCategoriesByLocale = {};

  @visibleForTesting
  static void resetPluralCategoryCache() => _pluralCategoriesByLocale.clear();

  static List<String> extractPlaceholders(String value) {
    final stripped = _stripPluralSelectGenderBlocks(value);
    final simple = RegExp(r'\{(\w+)\}');
    return simple.allMatches(stripped).map((m) => m.group(1)!).toSet().toList();
  }

  // Removes ICU plural/select/gender arg blocks so simple-placeholder
  // extraction doesn't pick up raw words from branch bodies (e.g. `{x}`
  // inside `one{x}`) as if they were placeholders.
  static String _stripPluralSelectGenderBlocks(String value) {
    final output = StringBuffer();
    var currentIndex = 0;
    final valueLength = value.length;
    while (currentIndex < valueLength) {
      final currentCharacter = value[currentIndex];
      if (currentCharacter == "'") {
        final quotedSectionEndIndex = _skipQuotedSection(
          value,
          currentIndex,
          valueLength,
        );
        output.write(value.substring(currentIndex, quotedSectionEndIndex));
        currentIndex = quotedSectionEndIndex;
        continue;
      }
      if (currentCharacter == '{') {
        final blockEndIndex = _findMatchingClose(
          value,
          currentIndex,
          valueLength,
        );
        final blockContents = value.substring(
          currentIndex + 1,
          blockEndIndex - 1,
        );
        if (_parseArgHeader(blockContents) != null) {
          currentIndex = blockEndIndex;
          continue;
        }
        output.write(value.substring(currentIndex, blockEndIndex));
        currentIndex = blockEndIndex;
        continue;
      }
      output.write(currentCharacter);
      currentIndex++;
    }
    return output.toString();
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

  /// Resolves the set of CLDR plural categories supported by [locale] by
  /// probing `package:intl`'s plural-rule registry. Falls back to the
  /// language subtag if the canonical locale is not registered. Returns
  /// `null` when neither form is in the registry; results are cached per
  /// canonical locale.
  static Set<String>? getPluralCategoriesForLocale(String locale) {
    final canonicalLocale = canonicalizeLocale(locale);
    if (_pluralCategoriesByLocale.containsKey(canonicalLocale)) {
      return _pluralCategoriesByLocale[canonicalLocale];
    }

    final resolvedCategories =
        _getPluralCategoriesFromIntlRegistry(canonicalLocale) ??
        _getPluralCategoriesFromIntlRegistry(
          _getLanguageSubtag(canonicalLocale),
        );
    final cachedCategories = resolvedCategories == null
        ? null
        : UnmodifiableSetView(resolvedCategories);

    _pluralCategoriesByLocale[canonicalLocale] = cachedCategories;
    if (cachedCategories == null) {
      _log.fine(
        () =>
            "Skipping plural-category validation for locale '$locale': "
            "not in package:intl's plural-rule registry.",
      );
    }
    return cachedCategories;
  }

  static String _getLanguageSubtag(String canonicalLocale) {
    final separatorIndex = canonicalLocale.indexOf('_');
    return separatorIndex == -1
        ? canonicalLocale
        : canonicalLocale.substring(0, separatorIndex);
  }

  static Set<String>? _getPluralCategoriesFromIntlRegistry(
    String localeCandidate,
  ) {
    final intlRegistryLocaleKey = _getIntlPluralRuleLocaleKey(localeCandidate);
    if (intlRegistryLocaleKey == null) return null;

    final pluralRule = plural_rules.pluralRules[intlRegistryLocaleKey];
    if (pluralRule == null) return null;

    final pluralCategories = <String>{};
    for (final probeNumber in _pluralCategoryProbeNumbers) {
      // Pass null precision for fractional probes so intl uses the actual
      // decimal count (v); the default precision 0 forces v=0, masking the
      // non-integer OTHER cases.
      plural_rules.startRuleEvaluation(
        probeNumber,
        probeNumber is int ? 0 : null,
      );
      pluralCategories.add(_getPluralCategoryFromPluralCase(pluralRule()));
    }
    return pluralCategories;
  }

  static String? _getIntlPluralRuleLocaleKey(String localeCandidate) {
    for (final registeredLocaleKey in plural_rules.pluralRules.keys) {
      if (registeredLocaleKey.toLowerCase() == localeCandidate) {
        return registeredLocaleKey;
      }
    }
    return null;
  }

  static String _getPluralCategoryFromPluralCase(
    plural_rules.PluralCase pluralCase,
  ) {
    switch (pluralCase) {
      case plural_rules.PluralCase.ZERO:
        return 'zero';
      case plural_rules.PluralCase.ONE:
        return 'one';
      case plural_rules.PluralCase.TWO:
        return 'two';
      case plural_rules.PluralCase.FEW:
        return 'few';
      case plural_rules.PluralCase.MANY:
        return 'many';
      case plural_rules.PluralCase.OTHER:
        return 'other';
    }
  }

  static ArbValidationResult validateTranslation(
    String sourceText,
    String translatedText, {
    String? targetLocale,
  }) {
    final syntaxError = validateIcuSyntax(translatedText);
    if (syntaxError != null) {
      return ArbValidationResult(isValid: false, error: syntaxError);
    }

    final sourceArgs = _extractIcuArguments(sourceText);
    final translatedArgs = _extractIcuArguments(translatedText);

    final argNameError = _validateArgNamePreservation(
      sourceArgs,
      translatedArgs,
    );
    if (argNameError != null) {
      return ArbValidationResult(isValid: false, error: argNameError);
    }

    final otherBranchError = _validateOtherBranches(translatedArgs);
    if (otherBranchError != null) {
      return ArbValidationResult(isValid: false, error: otherBranchError);
    }

    if (targetLocale != null) {
      final allowed = getPluralCategoriesForLocale(targetLocale);
      if (allowed != null) {
        final pluralError = _validatePluralCategories(
          translatedArgs,
          targetLocale,
          allowed,
        );
        if (pluralError != null) {
          return ArbValidationResult(isValid: false, error: pluralError);
        }
      }
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

  static String? _validateArgNamePreservation(
    List<_IcuArgument> sourceArgs,
    List<_IcuArgument> translatedArgs,
  ) {
    final translatedNames = <String>{};
    _collectArgNames(translatedArgs, translatedNames);
    return _findMissingSourceArg(sourceArgs, translatedNames);
  }

  static String? _findMissingSourceArg(
    List<_IcuArgument> args,
    Set<String> translatedNames,
  ) {
    for (final arg in args) {
      if (!translatedNames.contains(arg.name)) {
        return "ICU argument '${arg.name}' missing in translation";
      }
      final nested = _findMissingSourceArg(arg.nested, translatedNames);
      if (nested != null) return nested;
    }
    return null;
  }

  static void _collectArgNames(
    List<_IcuArgument> args,
    Set<String> out,
  ) {
    for (final arg in args) {
      out.add(arg.name);
      _collectArgNames(arg.nested, out);
    }
  }

  static String? _validateOtherBranches(List<_IcuArgument> args) {
    for (final arg in args) {
      if (!arg.branches.containsKey('other')) {
        return "missing 'other' branch in ${arg.type} argument '${arg.name}'";
      }
      final nested = _validateOtherBranches(arg.nested);
      if (nested != null) return nested;
    }
    return null;
  }

  static String? _validatePluralCategories(
    List<_IcuArgument> args,
    String locale,
    Set<String> allowed,
  ) {
    for (final arg in args) {
      if (arg.type == 'plural') {
        for (final keyword in arg.branches.keys) {
          if (keyword.startsWith('=')) continue;
          if (!allowed.contains(keyword)) {
            return "invalid plural category '$keyword' for locale '$locale' "
                '(allowed: ${_formatAllowedCategories(allowed)})';
          }
        }
      }
      final nested = _validatePluralCategories(arg.nested, locale, allowed);
      if (nested != null) return nested;
    }
    return null;
  }

  static String _formatAllowedCategories(Set<String> categories) {
    final sorted = categories.toList()
      ..sort(
        (a, b) => _cldrCategoryOrder.indexOf(a) - _cldrCategoryOrder.indexOf(b),
      );
    return sorted.join(', ');
  }

  static List<_IcuArgument> _extractIcuArguments(String value) {
    final out = <_IcuArgument>[];
    _walkIcuArguments(value, 0, value.length, out);
    return out;
  }

  static void _walkIcuArguments(
    String value,
    int start,
    int end,
    List<_IcuArgument> out,
  ) {
    var i = start;
    while (i < end) {
      final ch = value[i];
      if (ch == "'") {
        i = _skipQuotedSection(value, i, end);
        continue;
      }
      if (ch == '{') {
        final closeIdx = _findMatchingClose(value, i, end);
        final inner = value.substring(i + 1, closeIdx - 1);
        final header = _parseArgHeader(inner);
        if (header != null) {
          final branchesText = inner.substring(header.bodyStart);
          final branches = _parseBranches(branchesText);
          final nested = <_IcuArgument>[];
          for (final body in branches.values) {
            _walkIcuArguments(body, 0, body.length, nested);
          }
          out.add(
            _IcuArgument(
              name: header.name,
              type: header.type,
              branches: branches,
              nested: nested,
            ),
          );
        }
        i = closeIdx;
        continue;
      }
      i++;
    }
  }

  static int _skipQuotedSection(String value, int start, int end) {
    // value[start] == "'"
    if (start + 1 >= end) return start + 1;

    // '' = literal apostrophe.
    if (value[start + 1] == "'") return start + 2;

    // Apostrophe only quotes when followed by { or }.
    if (value[start + 1] != '{' && value[start + 1] != '}') return start + 1;

    var i = start + 2;
    while (i < end) {
      if (value[i] == "'") {
        if (i + 1 < end && value[i + 1] == "'") {
          i += 2;
        } else {
          return i + 1;
        }
      } else {
        i++;
      }
    }
    return i;
  }

  static int _findMatchingClose(String value, int openIdx, int end) {
    // value[openIdx] == '{'
    var depth = 0;
    var i = openIdx;
    while (i < end) {
      final ch = value[i];
      if (ch == "'") {
        i = _skipQuotedSection(value, i, end);
        continue;
      }
      if (ch == '{') {
        depth++;
      } else if (ch == '}') {
        depth--;
        if (depth == 0) return i + 1;
      }
      i++;
    }
    return end;
  }

  static _IcuArgHeader? _parseArgHeader(String inner) {
    final c1 = inner.indexOf(',');
    if (c1 == -1) return null;
    final name = inner.substring(0, c1).trim();
    if (name.isEmpty || !_isValidIdentifier(name)) return null;

    final c2 = inner.indexOf(',', c1 + 1);
    if (c2 == -1) return null;
    final type = inner.substring(c1 + 1, c2).trim();
    if (!_pluralSelectGenderTypes.contains(type)) return null;

    return _IcuArgHeader(name: name, type: type, bodyStart: c2 + 1);
  }

  static bool _isValidIdentifier(String s) {
    if (s.isEmpty) return false;
    for (var i = 0; i < s.length; i++) {
      final c = s.codeUnitAt(i);
      final isAlpha = (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 95;
      final isDigit = c >= 48 && c <= 57;
      if (i == 0 ? !isAlpha : !(isAlpha || isDigit)) return false;
    }
    return true;
  }

  static Map<String, String> _parseBranches(String text) {
    final result = <String, String>{};
    var i = 0;
    final end = text.length;
    while (i < end) {
      while (i < end && _isWhitespace(text[i])) {
        i++;
      }
      if (i >= end) break;

      final keywordStart = i;
      while (i < end && text[i] != '{' && !_isWhitespace(text[i])) {
        i++;
      }
      final keyword = text.substring(keywordStart, i);
      if (keyword.isEmpty) break;

      while (i < end && _isWhitespace(text[i])) {
        i++;
      }
      if (i >= end || text[i] != '{') break;

      final closeIdx = _findMatchingClose(text, i, end);
      final body = text.substring(i + 1, closeIdx - 1);
      result[keyword] = body;
      i = closeIdx;
    }
    return result;
  }

  static bool _isWhitespace(String ch) =>
      ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r';
}

class _IcuArgument {
  _IcuArgument({
    required this.name,
    required this.type,
    required this.branches,
    required this.nested,
  });

  final String name;
  final String type;
  final Map<String, String> branches;
  final List<_IcuArgument> nested;
}

class _IcuArgHeader {
  _IcuArgHeader({
    required this.name,
    required this.type,
    required this.bodyStart,
  });

  final String name;
  final String type;
  final int bodyStart;
}
