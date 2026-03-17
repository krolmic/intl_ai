# intl_ai

ARB files AI translation that works with `flutter_localizations` and `intl`.

- Reads your project’s `l10n.yaml`
- Detects target locales from existing ARB files
- Translates missing strings using AI

## Setup

Follow the official guide [Internationalizing Flutter apps](https://docs.flutter.dev/ui/internationalization) to set up `flutter_localizations` and `intl`.

Add `intl_ai` under `dev_dependencies` in your `pubspec.yaml`:

```yaml
dev_dependencies:
  intl_ai: ^0.1.0
```

Add the `ai_translation` section to your `l10n.yaml`:

```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart

ai_translation:
  provider: anthropic # options: anthropic | openai
  model: claude-haiku-4-5
  api_key_env: ANTHROPIC_API_KEY_INTL_AI
  ignore:
    - "DeepTime"
    - "Flutter"
  context: "A productivity and focus timer app for deep work sessions"
```

Export your API key:

```sh
export ANTHROPIC_API_KEY_INTL_AI=x
```

## Usage

```sh
# Translate missing keys
dart run intl_ai translate

# Translate all keys (overwrite existing)
dart run intl_ai translate --full

# Dry run — save output to lib/l10n/.intl_ai_dry_run.json without modifying ARBs
dart run intl_ai translate --dry-run

# Apply a previously saved dry run
dart run intl_ai translate --apply-dry-run

# Translate a specific locale
dart run intl_ai translate --locale de

# Enable verbose logging
dart run intl_ai translate --verbose
```

## Workflow

1. Add/modify keys in `app_en.arb`.
2. Run `dart run intl_ai translate`.
3. Run `fvm flutter pub get` to regenerate localizations code.
