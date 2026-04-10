# deep_link_orchestrator

A modular, type-safe deep link orchestration package for Flutter. Handles validation, deduplication, authentication gating, and dispatching with pluggable sources, policies, and handlers.

Built on top of [`app_links`](https://pub.dev/packages/app_links) with zero additional runtime dependencies.

## Features

- **Handler-based dispatching** -- each handler declares what it can handle and whether it requires authentication.
- **Typed intents** -- define concrete `DeepLinkIntent` subclasses with parsed fields; handlers match via `intent is ProfileIntent`.
- **Debounce & deduplication** -- prevents duplicate link processing from rapid-fire or replayed intents.
- **Authentication gating** -- automatically saves pending links when the user isn't authenticated and replays them after login.
- **Validation** -- reject links with unsupported schemes, hosts, or paths before they reach your handlers.
- **Pluggable architecture** -- swap out any component (source, validator, auth policy, pending store, logger) with your own implementation.
- **Cold & warm start** -- handles both the initial app launch link and links received while the app is running.

## Installation

```yaml
dependencies:
  deep_link_orchestrator: ^1.0.0
```

```bash
flutter pub get
```

## Quick start

### 1. Define your intents

Extend `DeepLinkIntent` with concrete types that carry parsed data:

```dart
import 'package:deep_link_orchestrator/deep_link_orchestrator.dart';

class ProfileIntent extends DeepLinkIntent {
  const ProfileIntent({
    required this.userId,
    required super.sourceId,
    required super.uri,
  });

  final String userId;
}

class InviteIntent extends DeepLinkIntent {
  const InviteIntent({
    required this.inviteCode,
    required super.sourceId,
    required super.uri,
  });

  final String inviteCode;
}
```

### 2. Create an intent resolver

The resolver converts raw intents from sources into your concrete types:

```dart
DeepLinkIntent resolveIntent(DeepLinkIntent intent) {
  final segments = intent.uri.pathSegments;
  final params = intent.uri.queryParameters;

  if (segments.firstOrNull == 'profile' && segments.length > 1) {
    return ProfileIntent(
      userId: segments[1],
      sourceId: intent.sourceId,
      uri: intent.uri,
    );
  }

  if (segments.firstOrNull == 'invite' && params.containsKey('code')) {
    return InviteIntent(
      inviteCode: params['code']!,
      sourceId: intent.sourceId,
      uri: intent.uri,
    );
  }

  return intent;
}
```

### 3. Create handlers

Each handler matches on a concrete intent type:

```dart
class ProfileHandler extends DeepLinkHandler {
  @override
  bool canHandle(DeepLinkIntent intent) => intent is ProfileIntent;

  @override
  Future<void> handle({
    required DeepLinkHandlerContext context,
    required DeepLinkIntent intent,
  }) async {
    final profile = intent as ProfileIntent;
    // Navigate to profile screen using profile.userId
  }
}

class InviteHandler extends DeepLinkHandler {
  @override
  bool get requiresAuthentication => true;

  @override
  bool canHandle(DeepLinkIntent intent) => intent is InviteIntent;

  @override
  Future<void> handle({
    required DeepLinkHandlerContext context,
    required DeepLinkIntent intent,
  }) async {
    final invite = intent as InviteIntent;
    // Handle invite using invite.inviteCode
  }
}
```

### 4. Wire it up

```dart
final orchestrator = DeepLinkOrchestrator(
  sources: [AppLinksDeepLinkSource()],
  intentResolver: resolveIntent,
  validationPolicy: DeepLinkValidator(
    supportedPaths: ['/profile', '/invite'],
    expectedHost: 'example.com',
    customScheme: 'myapp',
  ),
);

orchestrator.dispatcher.registerHandlers({
  ProfileIntent: ProfileHandler(...),
  InviteIntent: InviteHandler(...),
});

await orchestrator.initialize();
await orchestrator.checkInitialIntent();

// Dispose when done
await orchestrator.dispose();
```

## Architecture

```
┌─────────────────┐
│  DeepLinkSource  │  (AppLinksDeepLinkSource, or your own)
└────────┬────────┘
         │ RawDeepLinkIntent
         ▼
┌─────────────────────────┐
│  DeepLinkOrchestrator   │  debounce → dedup → validate → resolve → dispatch
└────────┬────────────────┘
         │ ProfileIntent / InviteIntent / ...
         ▼
┌─────────────────────┐
│  DeepLinkDispatcher  │  find matching handler → auth gate → handle
└────────┬────────────┘
         │
         ▼
┌─────────────────────┐
│  DeepLinkHandler     │  your application logic
└─────────────────────┘
```

### Processing pipeline

1. **Source** receives a raw URI and wraps it in a `RawDeepLinkIntent`.
2. **Orchestrator** debounces rapid-fire intents, then checks deduplication.
3. **Validation policy** rejects links with unsupported schemes/hosts/paths.
4. **Intent resolver** (optional) converts the raw intent into a concrete subclass with parsed fields.
5. **Dispatcher** looks up the handler by `intent.runtimeType` in its map, then confirms `canHandle`. If that handler has `requiresAuthentication == true` and the user isn't authenticated, the link is saved to the **pending store** for later replay. Otherwise, the handler processes the intent.

## Configuration

### Validation

Use `DeepLinkValidator` or implement `DeepLinkValidationPolicy`:

```dart
DeepLinkValidator(
  supportedPaths: ['/profile', '/settings'],
  expectedHost: 'example.com',
  customScheme: 'myapp',
)
```

This accepts `myapp://` (any host), `https://example.com/...`, and `https://www.example.com/...`.

### Authentication gating

Implement `DeepLinkAuthenticationPolicy` to let the orchestrator know when the user is signed in:

```dart
class MyAuthPolicy implements DeepLinkAuthenticationPolicy {
  @override
  bool get isAuthenticated => AuthService.instance.isLoggedIn;
}
```

When a handler has `requiresAuthentication == true` and the user isn't authenticated, the link URI is saved to the pending store. After login, call `orchestrator.checkInitialIntent()` to replay it.

### Deduplication

The default `DefaultDeepLinkDeduplicationStrategy` deduplicates by `sourceId:uri` forever — a second delivery of the same URI is always dropped until you call `resetDeduplication()`. This soaks up platform double-fires but prevents the user from opening the same link twice.

Use `TimeWindowDeepLinkDeduplicationStrategy` to get time-bounded dedupe: identical intents that arrive within the window are collapsed, but the same URI is handled again once the window expires.

```dart
DeepLinkOrchestrator(
  sources: [AppLinksDeepLinkSource()],
  deduplicationStrategy: TimeWindowDeepLinkDeduplicationStrategy(
    windowDuration: const Duration(milliseconds: 800),
  ),
)
```

| Scenario | Behavior |
|----------|----------|
| Same URI arrives 50 ms after last one | Collapsed — handler runs once |
| Same URI arrives 5 s after last one | Treated as new open — handler runs again |

Implement `DeepLinkDeduplicationStrategy` for fully custom logic:

```dart
class MyDeduplicationStrategy implements DeepLinkDeduplicationStrategy {
  @override
  String fingerprintOf(DeepLinkIntent intent) {
    // Return the same string to dedupe, a new string to allow.
    return '${intent.sourceId}:${intent.uri}';
  }
}
```

### Pending store

The package ships with `NoopDeepLinkPendingStore` (default) and `InMemoryDeepLinkPendingStore`. For persistence across app restarts, implement `DeepLinkPendingStore` with your own storage:

```dart
class SharedPrefsPendingStore implements DeepLinkPendingStore {
  @override
  Future<void> savePending(Uri uri) async { /* ... */ }

  @override
  Future<void> clearPending() async { /* ... */ }

  @override
  Uri? readPending() { /* ... */ }
}
```

### Dispatcher

`DeepLinkOrchestrator` creates a `DeepLinkDispatcher` by default. You can supply your own with an optional named `handlers` map (`Type` → `DeepLinkHandler`), or register handlers later via `registerHandler` / `registerHandlers`:

```dart
DeepLinkOrchestrator(
  sources: [AppLinksDeepLinkSource()],
  dispatcher: DeepLinkDispatcher(
    handlers: {
      ProfileIntent: ProfileHandler(...),
      InviteIntent: InviteHandler(...),
    },
  ),
);
```

To call the dispatcher yourself (e.g. in tests), use named arguments on `dispatch`:

```dart
final handled = await dispatcher.dispatch(
  context: DeepLinkHandlerContext(
    pendingStore: pendingStore,
    authPolicy: authPolicy,
    sharedData: const {},
  ),
  intent: resolvedIntent,
);
```

### Logging

Inject any `DeepLinkLogger`. The default `DeveloperDeepLinkLogger` writes to `dart:developer`'s `log()`. Use `NoopDeepLinkLogger` to silence output, or implement your own.

### Custom sources

Implement `DeepLinkSource` to receive links from other channels (push notifications, attribution SDKs, etc.):

```dart
class NotificationDeepLinkSource implements DeepLinkSource {
  @override
  String get id => 'notification';

  @override
  Future<void> initialize(DeepLinkIntentSink onIntent) async {
    // Listen to your notification stream and call onIntent(...)
  }

  @override
  Future<DeepLinkIntent?> getInitialIntent() async => null;

  @override
  Future<void> dispose() async {}
}
```

Then pass it alongside `AppLinksDeepLinkSource`:

```dart
DeepLinkOrchestrator(
  sources: [AppLinksDeepLinkSource(), NotificationDeepLinkSource()],
);
```

## API overview

| Class | Role |
|---|---|
| `DeepLinkOrchestrator` | Top-level entry point; wires sources, policies, resolver, and dispatcher. |
| `DeepLinkIntent` | Abstract base for all intents; extend it with parsed fields. |
| `RawDeepLinkIntent` | Concrete intent created by sources before resolution. |
| `DeepLinkHandler` | Abstract handler with `canHandle`, `requiresAuthentication`, and `handle(context:, intent:)`. |
| `DeepLinkDispatcher` | Registers handlers in a `Map<Type, DeepLinkHandler>` for O(1) dispatch by `intent.runtimeType`; constructor `handlers:`, methods `registerHandler`, `registerHandlers`, `dispatch(context:, intent:)`. |
| `DeepLinkValidator` | Built-in scheme/host/path validation. |
| `AppLinksDeepLinkSource` | `app_links` v7 integration (cold + warm start). |
| `DeepLinkLogger` | Logging interface with `DeveloperDeepLinkLogger` and `NoopDeepLinkLogger`. |

### Policy interfaces

| Interface | Purpose | Default |
|---|---|---|
| `DeepLinkValidationPolicy` | Accept or reject URIs | `AllowAllDeepLinkValidationPolicy` |
| `DeepLinkAuthenticationPolicy` | Report auth state | `AlwaysAuthenticatedPolicy` |
| `DeepLinkDeduplicationStrategy` | Fingerprint intents; built-ins: `DefaultDeepLinkDeduplicationStrategy` (forever) and `TimeWindowDeepLinkDeduplicationStrategy` (time-bounded) | `DefaultDeepLinkDeduplicationStrategy` |
| `DeepLinkPendingStore` | Persist/replay pending links | `NoopDeepLinkPendingStore` |

## Platform setup

This package uses [`app_links`](https://pub.dev/packages/app_links) under the hood. Follow the platform-specific setup instructions in the [app_links documentation](https://pub.dev/packages/app_links):

- **Android**: Add `intent-filter` entries in `AndroidManifest.xml` and host an `assetlinks.json` file.
- **iOS**: Enable Associated Domains in Xcode and host an `apple-app-site-association` file.
- **Desktop / Web**: See the app_links README for platform-specific configuration.

## License

MIT -- see [LICENSE](LICENSE).
