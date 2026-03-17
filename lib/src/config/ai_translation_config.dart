import 'package:meta/meta.dart';

@immutable
class AiTranslationConfig {
  const AiTranslationConfig({
    required this.provider,
    required this.model,
    required this.apiKeyEnv,
    this.ignore = const [],
    this.context,
  });

  factory AiTranslationConfig.fromYaml(Map<dynamic, dynamic> map) {
    final providerRaw = map['provider'] as String?;
    final provider = AiTranslationProvider.tryParse(providerRaw);
    if (provider == null) {
      throw FormatException(
        'ai_translation.provider must be "openai" or "anthropic"'
        '${providerRaw != null ? ', got: $providerRaw' : ' (missing)'}',
      );
    }

    final model = map['model'];
    if (model == null) {
      throw const FormatException('ai_translation.model is required');
    }

    final apiKeyEnv = map['api_key_env'];
    if (apiKeyEnv == null) {
      throw const FormatException('ai_translation.api_key_env is required');
    }

    final ignoreRaw = map['ignore'];
    final ignore = <String>[];
    if (ignoreRaw != null) {
      if (ignoreRaw is List) {
        for (final item in ignoreRaw) {
          ignore.add(item.toString());
        }
      } else {
        throw const FormatException(
          'ai_translation.ignore must be a list of strings',
        );
      }
    }

    final context = map['context'] as String?;

    return AiTranslationConfig(
      provider: provider,
      model: model.toString(),
      apiKeyEnv: apiKeyEnv.toString(),
      ignore: List.unmodifiable(ignore),
      context: context,
    );
  }

  final AiTranslationProvider provider;
  final String model;
  final String apiKeyEnv;
  final List<String> ignore;
  final String? context;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiTranslationConfig &&
          provider == other.provider &&
          model == other.model &&
          apiKeyEnv == other.apiKeyEnv &&
          context == other.context;

  @override
  int get hashCode => Object.hash(provider, model, apiKeyEnv, context);
}

enum AiTranslationProvider {
  openai,
  anthropic;

  static AiTranslationProvider? tryParse(String? value) {
    if (value == null) return null;
    for (final provider in values) {
      if (provider.name == value) return provider;
    }
    return null;
  }
}
