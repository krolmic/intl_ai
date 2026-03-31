# Changelog

## 0.2.0

### Breaking changes

- Rename `ignore` to `do_not_translate_phrases` in `AiTranslationConfig` ([#4](https://github.com/krolmic/intl_ai/issues/4)).

### Added

- Preserve and merge metadata (`@@locale`, `@@last_modified`, etc.) from template ARB into translated files ([#17](https://github.com/krolmic/intl_ai/issues/17)).
- Validate translated result for missing keys and require all keys in the prompt ([#19](https://github.com/krolmic/intl_ai/issues/19)).
- Add `stop_reason` / `finish_reason` validation and increase `max_tokens` for Anthropic ([#18](https://github.com/krolmic/intl_ai/issues/18)).

### Fixed

- Use `jsonEncode` in translation repository for correct JSON escaping ([#24](https://github.com/krolmic/intl_ai/issues/24)).

## 0.1.0

- Initial release.
- ARB AI translation via OpenAI and Anthropic providers.
- Incremental and full translation modes.
- Dry-run mode with review file output.
- ICU/placeholder validation.
