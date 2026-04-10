import '../deep_link_intent.dart';

// ---------------------------------------------------------------------------
// Abstract policies
// ---------------------------------------------------------------------------

/// Determines whether a URI is acceptable for processing.
///
/// Implement this interface to enforce app-specific rules such as allowed
/// schemes, hosts, or path patterns. Return a non-null failure reason
/// string to reject the link, or `null` to allow it through.
///
/// See also:
/// - [AllowAllDeepLinkValidationPolicy] — a no-op implementation.
/// - [DeepLinkValidator] in `deep_link_validator.dart` — a ready-made
///   scheme/host/path validator.
abstract interface class DeepLinkValidationPolicy {
  /// Returns a human-readable reason if [uri] should be rejected, or `null`
  /// if the URI is valid.
  String? failureReason(Uri uri);
}

/// Indicates whether the current user session is authenticated.
///
/// The [DeepLinkDispatcher] queries this policy before invoking any handler
/// whose [DeepLinkHandler.requiresAuthentication] flag is `true`. If the
/// user is not authenticated the intent is persisted via
/// [DeepLinkPendingStore] and replayed after login.
///
/// See also:
/// - [AlwaysAuthenticatedPolicy] — a no-op implementation for apps without
///   authentication.
abstract interface class DeepLinkAuthenticationPolicy {
  /// Whether the user is currently authenticated.
  bool get isAuthenticated;
}

/// Computes a stable fingerprint for a [DeepLinkIntent].
///
/// [DeepLinkOrchestrator] uses the fingerprint to suppress duplicate intents
/// (e.g. the same URI arriving from multiple sources within one interaction).
///
/// See also:
/// - [DefaultDeepLinkDeduplicationStrategy] — fingerprints by sourceId + URI.
/// - [TimeWindowDeepLinkDeduplicationStrategy] — fingerprints within a time
///   window so the same URI can be re-processed after a configurable delay.
abstract interface class DeepLinkDeduplicationStrategy {
  /// Returns a fingerprint string that uniquely identifies [intent].
  ///
  /// Two intents that should be considered duplicates must return the same
  /// string.
  String fingerprintOf(DeepLinkIntent intent);
}

/// Persists a pending [Uri] so it can be replayed after authentication.
///
/// When a handler requires authentication but the user is not yet logged in,
/// the orchestrator saves the URI with [savePending] and replays it via
/// [readPending] once authentication succeeds.
///
/// See also:
/// - [NoopDeepLinkPendingStore] — discards all pending URIs (default).
/// - [InMemoryDeepLinkPendingStore] — stores one URI in memory.
abstract interface class DeepLinkPendingStore {
  /// Persists [uri] so it can be replayed after authentication.
  Future<void> savePending(Uri uri);

  /// Removes any previously stored pending URI.
  Future<void> clearPending();

  /// Returns the stored pending URI, or `null` if none exists.
  Uri? readPending();
}

// ---------------------------------------------------------------------------
// Default implementations
// ---------------------------------------------------------------------------

/// A [DeepLinkValidationPolicy] that accepts every URI unconditionally.
///
/// Use this (or omit the `validationPolicy` parameter on
/// [DeepLinkOrchestrator]) when URI filtering is handled elsewhere, such as
/// in the platform's `AndroidManifest.xml` or `Info.plist`.
class AllowAllDeepLinkValidationPolicy implements DeepLinkValidationPolicy {
  /// Creates an [AllowAllDeepLinkValidationPolicy].
  const AllowAllDeepLinkValidationPolicy();

  /// Always returns `null`, allowing every URI to proceed.
  @override
  String? failureReason(Uri uri) => null;
}

/// A [DeepLinkAuthenticationPolicy] that always reports the user as
/// authenticated.
///
/// Use this for apps that do not have a login flow, or during development
/// when you want to skip authentication gating.
class AlwaysAuthenticatedPolicy implements DeepLinkAuthenticationPolicy {
  /// Creates an [AlwaysAuthenticatedPolicy].
  const AlwaysAuthenticatedPolicy();

  /// Always returns `true`.
  @override
  bool get isAuthenticated => true;
}

/// A [DeepLinkDeduplicationStrategy] that fingerprints by `sourceId:uri`.
///
/// Two intents with identical source identifiers and URIs are treated as
/// duplicates regardless of when they arrive. This is appropriate for most
/// apps where re-navigating to the same destination in the same session is
/// undesirable.
class DefaultDeepLinkDeduplicationStrategy
    implements DeepLinkDeduplicationStrategy {
  /// Creates a [DefaultDeepLinkDeduplicationStrategy].
  const DefaultDeepLinkDeduplicationStrategy();

  /// Returns `'${intent.sourceId}:${intent.uri}'`.
  @override
  String fingerprintOf(DeepLinkIntent intent) =>
      '${intent.sourceId}:${intent.uri}';
}

/// A [DeepLinkDeduplicationStrategy] that suppresses duplicates only within
/// a rolling time window.
///
/// After [windowDuration] has elapsed the same URI is treated as a new
/// intent, allowing intentional re-navigation to the same destination.
///
/// This strategy is stateful; create a single instance and reuse it for the
/// lifetime of the orchestrator.
class TimeWindowDeepLinkDeduplicationStrategy
    implements DeepLinkDeduplicationStrategy {
  /// Creates a [TimeWindowDeepLinkDeduplicationStrategy].
  ///
  /// [windowDuration] controls how long after the first occurrence of a URI
  /// a duplicate is suppressed. Defaults to one second.
  TimeWindowDeepLinkDeduplicationStrategy({
    this.windowDuration = const Duration(seconds: 1),
  });

  /// The duration during which identical intents are considered duplicates.
  final Duration windowDuration;

  String? _lastEmittedFingerprint;
  String? _lastSemanticKey;
  DateTime? _expiresAt;

  @override
  String fingerprintOf(DeepLinkIntent intent) {
    final semanticKey = '${intent.sourceId}:${intent.uri}';
    final now = DateTime.now();

    if (_lastSemanticKey == semanticKey && now.isBefore(_expiresAt!)) {
      return _lastEmittedFingerprint!;
    }

    _lastSemanticKey = semanticKey;
    _expiresAt = now.add(windowDuration);
    return _lastEmittedFingerprint =
        '$semanticKey#${now.microsecondsSinceEpoch}';
  }
}

/// A [DeepLinkPendingStore] that silently discards all pending URIs.
///
/// This is the default store used by [DeepLinkOrchestrator]. Choose it when
/// your app has no authentication flow or when you prefer not to replay
/// deferred deep links.
class NoopDeepLinkPendingStore implements DeepLinkPendingStore {
  /// Creates a [NoopDeepLinkPendingStore].
  const NoopDeepLinkPendingStore();

  /// Does nothing.
  @override
  Future<void> savePending(Uri uri) async {}

  /// Does nothing.
  @override
  Future<void> clearPending() async {}

  /// Always returns `null`.
  @override
  Uri? readPending() => null;
}

/// A [DeepLinkPendingStore] that holds one pending [Uri] in memory.
///
/// Stores the most-recently deferred URI in a private field. The stored URI
/// is lost when the process is killed; use a persistent store (e.g.
/// `SharedPreferences`) for cross-launch replay.
class InMemoryDeepLinkPendingStore implements DeepLinkPendingStore {
  Uri? _pending;

  /// Stores [uri], overwriting any previously stored value.
  @override
  Future<void> savePending(Uri uri) async => _pending = uri;

  /// Clears the stored URI.
  @override
  Future<void> clearPending() async => _pending = null;

  /// Returns the stored URI, or `null` if none has been saved.
  @override
  Uri? readPending() => _pending;
}

// ---------------------------------------------------------------------------
// Handler context
// ---------------------------------------------------------------------------

/// Immutable context passed to every [DeepLinkHandler.handle] call.
///
/// Provides handlers with access to shared infrastructure (auth policy,
/// pending store, and arbitrary shared data) without coupling them to the
/// orchestrator directly.
class DeepLinkHandlerContext {
  /// Creates a [DeepLinkHandlerContext].
  const DeepLinkHandlerContext({
    required this.pendingStore,
    required this.authPolicy,
    this.sharedData = const <String, Object?>{},
  });

  /// The policy used to check whether the user is authenticated.
  final DeepLinkAuthenticationPolicy authPolicy;

  /// The store used to persist and retrieve deferred deep link URIs.
  final DeepLinkPendingStore pendingStore;

  /// Arbitrary data shared across all handlers in a single orchestrator.
  ///
  /// Use this map to propagate app-level context (e.g. a navigator key or
  /// a dependency-injection container) without hard-coding dependencies in
  /// each handler.
  final Map<String, Object?> sharedData;
}
