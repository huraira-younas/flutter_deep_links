## 1.0.0

- Initial release.
- Handler-based deep link orchestration with pluggable architecture.
- Abstract `DeepLinkIntent` base class for typed intent hierarchies.
- Optional `DeepLinkIntentResolver` to convert raw intents into concrete subtypes.
- Built-in `AppLinksDeepLinkSource` wrapping `app_links` v7.
- Debounce, deduplication, validation, and per-handler authentication gating.
- Extensible via `DeepLinkSource`, `DeepLinkHandler`, and policy interfaces.
