## 1.0.1

- Fixed pubspec description length to comply with pub.dev requirements (60–180 characters).
- Added dartdoc comments to 100% of the public API surface across all library files.

## 1.0.0

- Initial release.
- Handler-based deep link orchestration with pluggable architecture.
- Abstract `DeepLinkIntent` base class for typed intent hierarchies.
- Optional `DeepLinkIntentResolver` to convert raw intents into concrete subtypes.
- Built-in `AppLinksDeepLinkSource` wrapping `app_links` v7.
- Debounce, deduplication, validation, and per-handler authentication gating.
- Extensible via `DeepLinkSource`, `DeepLinkHandler`, and policy interfaces.
